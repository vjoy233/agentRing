//
//  CodingPlanMapperChecks.swift
//  Agent Ring
//
//  GLM / Kimi Coding Plan mapper 行为测试（standalone，由 Scripts/test-coding-plan-mapper.sh 编译运行）
//  fixture 来自 2026-09-23 端点实测响应（脱敏）。
//

import Foundation

@main
struct CodingPlanMapperChecks {
    static var failures = 0

    static func check(_ name: String, _ condition: Bool, _ detail: @autoclosure () -> String = "") {
        if condition {
            print("PASS: \(name)")
        } else {
            failures += 1
            print("FAIL: \(name)  \(detail())")
        }
    }

    static func approxEqual(_ a: Double, _ b: Double, tolerance: Double = 0.0001) -> Bool {
        abs(a - b) <= tolerance
    }

    static func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: json.data(using: .utf8)!)
    }

    static func main() {
        // MARK: - GLM

        let glmFixture = """
        {"code":200,"msg":"操作成功","success":true,"data":{"limits":[
        {"type":"TIME_LIMIT","unit":5,"number":1,"usage":4000,"currentValue":114,"remaining":3886,"percentage":2,"nextResetTime":1791338592997},
        {"type":"TOKENS_LIMIT","unit":3,"number":5,"percentage":5,"nextResetTime":1790143338507},
        {"type":"TOKENS_LIMIT","unit":6,"number":1,"percentage":50,"nextResetTime":1790301792961}
        ],"level":"max"}}
        """

        do {
            let usage = try decode(GlmUsageResponse.self, glmFixture).toUsageData()

            check("GLM primary=5h(最近重置)", usage.primary?.percentage == 5, "got \(usage.primary?.percentage ?? -1)")
            let expectedPrimaryReset = Date(timeIntervalSince1970: TimeInterval(1790143338507) / 1000)
            check(
                "GLM primary.resetsAt 毫秒转 Date",
                usage.primary?.resetsAt == expectedPrimaryReset,
                "got \(String(describing: usage.primary?.resetsAt))"
            )
            check("GLM secondary=7d(最远重置)", usage.secondary?.percentage == 50, "got \(usage.secondary?.percentage ?? -1)")
            let expectedSecondaryReset = Date(timeIntervalSince1970: TimeInterval(1790301792961) / 1000)
            check("GLM secondary.resetsAt 毫秒转 Date", usage.secondary?.resetsAt == expectedSecondaryReset)
            check("GLM planLevel 透传", usage.planLevel == "max", "got \(usage.planLevel ?? "nil")")

            // TIME_LIMIT(MCP 月配额)必须被忽略
            check(
                "GLM TIME_LIMIT 被忽略",
                usage.primary?.percentage != 2 && usage.secondary?.percentage != 2,
                "TIME_LIMIT percentage 泄漏进了窗口"
            )
        } catch {
            check("GLM fixture 解码", false, "\(error)")
        }

        // 乱序返回 + 单条 TOKENS_LIMIT + 钳制
        do {
            let single = try decode(
                GlmUsageResponse.self,
                """
                {"code":200,"data":{"limits":[
                {"type":"TOKENS_LIMIT","unit":6,"number":1,"percentage":120,"nextResetTime":1790301792961}
                ],"level":"lite"}}
                """
            ).toUsageData()
            check(
                "GLM 单条 TOKENS_LIMIT → primary=该条, secondary=nil",
                single.primary?.percentage == 100 && single.secondary == nil,
                "primary=\(single.primary?.percentage ?? -1) secondary=\(String(describing: single.secondary))"
            )
            check("GLM percentage 钳制到 100", single.primary?.percentage == 100, "got \(single.primary?.percentage ?? -1)")

            let reversed = try decode(
                GlmUsageResponse.self,
                """
                {"code":200,"data":{"limits":[
                {"type":"TOKENS_LIMIT","unit":6,"number":1,"percentage":40,"nextResetTime":1790301792961},
                {"type":"TOKENS_LIMIT","unit":3,"number":5,"percentage":10,"nextResetTime":1790143338507}
                ],"level":null}}
                """
            ).toUsageData()
            check(
                "GLM 乱序返回按 nextResetTime 排序识别",
                reversed.primary?.percentage == 10 && reversed.secondary?.percentage == 40,
                "primary=\(reversed.primary?.percentage ?? -1) secondary=\(reversed.secondary?.percentage ?? -1)"
            )
        } catch {
            check("GLM 边界 fixture 解码", false, "\(error)")
        }

        // HTTP 200 但响应体报错：key 失效时智谱把 code=401 放在 body 里
        do {
            let errorBody = try decode(
                GlmUsageResponse.self,
                """
                {"code":401,"msg":"API Key 无效","success":false}
                """
            )
            check("GLM 响应体 code=401 判为错误载荷", errorBody.isErrorPayload)
            let errorUsage = errorBody.toUsageData()
            check(
                "GLM 错误载荷 map 后无窗口数据",
                errorUsage.primary == nil && errorUsage.secondary == nil
            )

            let nullData = try decode(
                GlmUsageResponse.self,
                """
                {"code":200,"data":null}
                """
            )
            check("GLM data 缺失判为错误载荷", nullData.isErrorPayload)
        } catch {
            check("GLM 错误载荷 fixture 解码", false, "\(error)")
        }

        // MARK: - Kimi

        let kimiFixture = """
        {"usage":{"limit":"100","used":"59","remaining":"41","resetTime":"2026-09-25T06:04:48.581180Z"},
        "limits":[{"window":{"duration":300,"timeUnit":"TIME_UNIT_MINUTE"},"detail":{"limit":"100","used":"7","remaining":"93","resetTime":"2026-09-23T04:04:48.581180Z"}}],
        "booster_wallet":{"userId":"test-user-001","usages":{"limit_5h":{"used_ratio":0.069053,"reset_time":"2026-09-23T04:04:47Z"},"limit_7d":{"used_ratio":0.592841,"reset_time":"2026-09-25T06:04:47Z"}}}}
        """

        do {
            let usage = try decode(KimiUsageResponse.self, kimiFixture).toUsageData()

            check("Kimi 字符串数字解码 primary=7%", approxEqual(usage.primary?.percentage ?? -1, 7), "got \(usage.primary?.percentage ?? -1)")
            check(
                "Kimi primary.resetTime 带微秒 ISO8601",
                KimiUsageMapper.parseResetTime("2026-09-23T04:04:48.581180Z") == usage.primary?.resetsAt,
                "got \(String(describing: usage.primary?.resetsAt))"
            )
            // 7d 走顶层 usage 回退
            check("Kimi secondary 回退顶层 usage=59%", approxEqual(usage.secondary?.percentage ?? -1, 59), "got \(usage.secondary?.percentage ?? -1)")
            check("Kimi userId 透传", usage.userId == "test-user-001", "got \(usage.userId ?? "nil")")
            check("Kimi 无小数秒 ISO8601 可解析", KimiUsageMapper.parseResetTime("2026-09-23T04:04:47Z") != nil)
        } catch {
            check("Kimi fixture 解码", false, "\(error)")
        }

        do {
            // limits 里带 weekly(duration=10080)时优先于顶层 usage
            let withWeekly = try decode(
                KimiUsageResponse.self,
                """
                {"usage":{"limit":"100","used":"59","remaining":"41","resetTime":"2026-09-25T06:04:48Z"},
                "limits":[
                {"window":{"duration":300,"timeUnit":"TIME_UNIT_MINUTE"},"detail":{"limit":"100","used":"7","remaining":"93","resetTime":"2026-09-23T04:04:48Z"}},
                {"window":{"duration":10080,"timeUnit":"TIME_UNIT_MINUTE"},"detail":{"limit":"200","used":"100","remaining":"100","resetTime":"2026-10-01T00:00:00Z"}}
                ]}
                """
            ).toUsageData()
            check(
                "Kimi limits 含 weekly 时优先(50% 而非 59%)",
                approxEqual(withWeekly.secondary?.percentage ?? -1, 50),
                "got \(withWeekly.secondary?.percentage ?? -1)"
            )

            // used 缺失时用 limit − remaining 推导
            let noUsed = try decode(
                KimiUsageResponse.self,
                """
                {"usage":null,"limits":[{"window":{"duration":300,"timeUnit":"TIME_UNIT_MINUTE"},"detail":{"limit":"100","remaining":"25","resetTime":"2026-09-23T04:04:48Z"}}]}
                """
            ).toUsageData()
            check("Kimi used 缺失 → limit−remaining=75%", approxEqual(noUsed.primary?.percentage ?? -1, 75), "got \(noUsed.primary?.percentage ?? -1)")

            // limits/usage 全空 → booster_wallet.usages 兜底
            let boosterOnly = try decode(
                KimiUsageResponse.self,
                """
                {"usage":null,"limits":[],"booster_wallet":{"userId":"u2","usages":{"limit_5h":{"used_ratio":0.25,"reset_time":"2026-09-23T10:00:00Z"},"limit_7d":{"used_ratio":0.5,"reset_time":"2026-09-29T10:00:00Z"}}}}
                """
            ).toUsageData()
            check("Kimi booster 兜底 primary=25%", approxEqual(boosterOnly.primary?.percentage ?? -1, 25), "got \(boosterOnly.primary?.percentage ?? -1)")
            check("Kimi booster 兜底 secondary=50%", approxEqual(boosterOnly.secondary?.percentage ?? -1, 50), "got \(boosterOnly.secondary?.percentage ?? -1)")

            // used 与 remaining 同时缺失：不能退化为 limit − 0 = 100%，应返回 nil 走 booster 兜底
            let noUsedNoRemaining = try decode(
                KimiUsageResponse.self,
                """
                {"usage":null,"limits":[{"window":{"duration":300,"timeUnit":"TIME_UNIT_MINUTE"},"detail":{"limit":"100","resetTime":"2026-09-23T04:04:48Z"}}],
                "booster_wallet":{"userId":"u3","usages":{"limit_5h":{"used_ratio":0.3,"reset_time":"2026-09-23T04:04:47Z"}}}}
                """
            ).toUsageData()
            check(
                "Kimi used/remaining 双缺失不误报 100%（走 booster 兜底=30%）",
                approxEqual(noUsedNoRemaining.primary?.percentage ?? -1, 30),
                "got \(noUsedNoRemaining.primary?.percentage ?? -1)"
            )

            // timeUnit 非分钟：该 entry 不参与窗口分类，防上游改单位后 duration 数值被静默误读
            let wrongUnit = try decode(
                KimiUsageResponse.self,
                """
                {"usage":{"limit":"100","used":"59","remaining":"41","resetTime":"2026-09-25T06:04:48Z"},
                "limits":[{"window":{"duration":300,"timeUnit":"TIME_UNIT_SECOND"},"detail":{"limit":"100","used":"7","remaining":"93","resetTime":"2026-09-23T04:04:48Z"}}]}
                """
            ).toUsageData()
            check(
                "Kimi timeUnit 非分钟的 entry 被跳过（primary=nil）",
                wrongUnit.primary == nil,
                "got \(String(describing: wrongUnit.primary))"
            )
            check(
                "Kimi 跳过后 7d 仍走顶层 usage 回退=59%",
                approxEqual(wrongUnit.secondary?.percentage ?? -1, 59),
                "got \(wrongUnit.secondary?.percentage ?? -1)"
            )

            // 全空响应：primary/secondary 都为 nil，即 service 层 noData 判定的输入
            let empty = try decode(
                KimiUsageResponse.self,
                """
                {"usage":null,"limits":[]}
                """
            ).toUsageData()
            check(
                "Kimi 全空响应无窗口数据（noData 输入）",
                empty.primary == nil && empty.secondary == nil
            )
        } catch {
            check("Kimi 边界 fixture 解码", false, "\(error)")
        }

        // MARK: - 汇总

        if failures == 0 {
            print("All GLM/Kimi mapper checks passed.")
        } else {
            print("\(failures) check(s) FAILED")
            exit(1)
        }
    }
}
