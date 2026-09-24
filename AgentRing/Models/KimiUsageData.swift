//
//  KimiUsageData.swift
//  Agent Ring
//

import Foundation

// MARK: - 内部数据模型

/// Kimi Coding Plan 使用量数据（api.kimi.com/coding）
struct KimiUsageData: Sendable {
    /// 5小时窗口用量（primary）
    let primary: LimitData?
    /// 7天窗口用量（secondary）
    let secondary: LimitData?
    /// 账号标识（响应 booster_wallet.userId，用于多账号去重展示）
    let userId: String?

    struct LimitData: Sendable {
        /// 当前使用百分比 (0-100)
        let percentage: Double
        /// 重置时间
        let resetsAt: Date?
    }
}

// MARK: - API 响应模型

/// GET https://api.kimi.com/coding/v1/usages 响应模型
/// 实测数字字段全部以字符串返回（"100"），resetTime 为带微秒的 ISO8601。
nonisolated struct KimiUsageResponse: Codable, Sendable {
    /// 顶层汇总，实测对应 7 天窗口（resetTime 与 7d 重置时间一致）
    let usage: WindowSummary?
    let limits: [LimitEntry]?
    let boosterWallet: BoosterWallet?

    struct WindowSummary: Codable, Sendable {
        let limit: FlexibleNumber?
        let used: FlexibleNumber?
        let remaining: FlexibleNumber?
        let resetTime: String?
    }

    struct LimitEntry: Codable, Sendable {
        let window: Window?
        let detail: WindowSummary?
    }

    struct Window: Codable, Sendable {
        /// 窗口时长（分钟）：300 = 5 小时，10080 = 7 天
        let duration: Int?
        let timeUnit: String?
    }

    struct BoosterWallet: Codable, Sendable {
        let userId: String?
        let usages: Usages?

        struct Usages: Codable, Sendable {
            let limit5h: WindowUsage?
            let limit7d: WindowUsage?

            enum CodingKeys: String, CodingKey {
                case limit5h = "limit_5h"
                case limit7d = "limit_7d"
            }
        }

        struct WindowUsage: Codable, Sendable {
            /// 已用比例 (0-1)
            let usedRatio: Double?
            let resetTime: String?

            enum CodingKeys: String, CodingKey {
                case usedRatio = "used_ratio"
                case resetTime = "reset_time"
            }
        }
    }

    /// 字符串/数字兼容解码（Kimi 把数字编码成 "100" 这类字符串）
    struct FlexibleNumber: Codable, Sendable {
        let value: Double?

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if container.decodeNil() {
                value = nil
            } else if let doubleValue = try? container.decode(Double.self) {
                value = doubleValue
            } else if let stringValue = try? container.decode(String.self) {
                value = Double(stringValue)
            } else {
                value = nil
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            if let value {
                try container.encode(value)
            } else {
                try container.encodeNil()
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case usage, limits
        case boosterWallet = "booster_wallet"
    }

    func toUsageData() -> KimiUsageData {
        KimiUsageMapper.map(self)
    }
}

// MARK: - Mapper

nonisolated enum KimiUsageMapper {
    static let fiveHourDuration = 300
    static let weeklyDuration = 10080

    /// 主路径：limits[] 中 duration=300 → 5h、duration=10080 → 7d；
    /// 7d 缺失时回退顶层 usage；仍取不到再回退 booster_wallet.usages（字段最规整的备选路径）。
    /// booster_wallet 余额 / 加油包数据不展示（A10）。
    static func map(_ response: KimiUsageResponse) -> KimiUsageData {
        func entry(duration: Int) -> KimiUsageResponse.WindowSummary? {
            response.limits?.first { entry in
                guard entry.window?.duration == duration else { return false }
                // 单位字段存在时必须是分钟，防上游改单位后 duration 数值被静默误读
                if let unit = entry.window?.timeUnit, !unit.isEmpty,
                   unit != "TIME_UNIT_MINUTE" {
                    return false
                }
                return true
            }?.detail
        }

        let primary = entry(duration: fiveHourDuration).flatMap { limitData(from: $0) }
            ?? response.boosterWallet?.usages?.limit5h.map { ratioLimitData(from: $0) }

        let secondary = entry(duration: weeklyDuration).flatMap { limitData(from: $0) }
            ?? response.usage.flatMap { limitData(from: $0) }
            ?? response.boosterWallet?.usages?.limit7d.map { ratioLimitData(from: $0) }

        return KimiUsageData(
            primary: primary,
            secondary: secondary,
            userId: response.boosterWallet?.userId
        )
    }

    /// limit/used/remaining 汇总：percentage = used / limit（used 缺失时用 limit − remaining 推导）。
    /// used 与 remaining 都缺失时无法推导，返回 nil 走 booster_wallet 兜底，
    /// 不能退化为 limit − 0 = 100% 造成「额度用尽」误报。
    static func limitData(from summary: KimiUsageResponse.WindowSummary) -> KimiUsageData.LimitData? {
        guard let limit = summary.limit?.value, limit > 0 else { return nil }
        guard let used = summary.used?.value ?? summary.remaining?.value.map({ limit - $0 }) else {
            return nil
        }
        return KimiUsageData.LimitData(
            percentage: min(100, max(0, used / limit * 100)),
            resetsAt: parseResetTime(summary.resetTime)
        )
    }

    /// booster_wallet.usages：直接给 used_ratio（0-1 小数）+ reset_time
    static func ratioLimitData(from usage: KimiUsageResponse.BoosterWallet.WindowUsage) -> KimiUsageData.LimitData {
        KimiUsageData.LimitData(
            percentage: min(100, max(0, (usage.usedRatio ?? 0) * 100)),
            resetsAt: parseResetTime(usage.resetTime)
        )
    }

    /// resetTime 为带微秒的 ISO8601（…T06:04:48.581180Z），部分字段无小数秒，两种都要能解
    static func parseResetTime(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractional.date(from: value) {
            return date
        }
        let basic = ISO8601DateFormatter()
        basic.formatOptions = [.withInternetDateTime]
        return basic.date(from: value)
    }
}
