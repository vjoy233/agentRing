//
//  GlmUsageData.swift
//  Agent Ring
//

import Foundation

// MARK: - 内部数据模型

/// GLM Coding Plan 使用量数据（智谱 bigmodel.cn）
struct GlmUsageData: Sendable {
    /// 5小时窗口用量（primary）
    let primary: LimitData?
    /// 7天窗口用量（secondary）
    let secondary: LimitData?
    /// Coding Plan 档位（lite / pro / max 等），仅在账号卡展示
    let planLevel: String?

    struct LimitData: Sendable {
        /// 当前使用百分比 (0-100)
        let percentage: Double
        /// 重置时间
        let resetsAt: Date?
    }
}

// MARK: - API 响应模型

/// GET https://bigmodel.cn/api/monitor/usage/quota/limit 响应模型
nonisolated struct GlmUsageResponse: Codable, Sendable {
    let code: Int?
    let msg: String?
    let success: Bool?
    let data: DataPayload?

    struct DataPayload: Codable, Sendable {
        let limits: [LimitEntry]?
        let level: String?
    }

    struct LimitEntry: Codable, Sendable {
        let type: String?
        let unit: Int?
        let number: Int?
        /// 已用百分比 (0-100)
        let percentage: Double?
        /// 重置时间（毫秒时间戳）
        let nextResetTime: Int64?
    }

    /// HTTP 200 但响应体报错：key 失效时智谱把 code=401 放在 body 里
    var isErrorPayload: Bool {
        code != 200 || data == nil
    }

    func toUsageData() -> GlmUsageData {
        GlmUsageMapper.map(self)
    }
}

// MARK: - Mapper

nonisolated enum GlmUsageMapper {
    /// 两条 TOKENS_LIMIT 中 nextResetTime 最近的是 5 小时窗口、最远的是 7 天窗口；
    /// 不依赖 unit/number 编码，智谱调整档位编码时依旧稳定。
    /// TIME_LIMIT 是 MCP 月配额（搜索次数），与 token 无关，忽略。
    static func map(_ response: GlmUsageResponse) -> GlmUsageData {
        let tokens = (response.data?.limits ?? [])
            .filter { $0.type == "TOKENS_LIMIT" }
            .compactMap { entry -> (resetTime: Int64, entry: GlmUsageResponse.LimitEntry)? in
                guard let resetTime = entry.nextResetTime else { return nil }
                return (resetTime, entry)
            }
            .sorted { $0.resetTime < $1.resetTime }

        let primary = tokens.first.map { limitData(from: $0.entry) }
        let secondary = tokens.count > 1 ? limitData(from: tokens[tokens.count - 1].entry) : nil

        return GlmUsageData(
            primary: primary,
            secondary: secondary,
            planLevel: response.data?.level
        )
    }

    static func limitData(from entry: GlmUsageResponse.LimitEntry) -> GlmUsageData.LimitData {
        GlmUsageData.LimitData(
            percentage: clampPercentage(entry.percentage),
            resetsAt: entry.nextResetTime.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
        )
    }

    static func clampPercentage(_ value: Double?) -> Double {
        min(100, max(0, value ?? 0))
    }
}
