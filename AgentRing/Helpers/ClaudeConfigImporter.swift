//
//  ClaudeConfigImporter.swift
//  Agent Ring
//

import Foundation

/// 从本机 Claude Code 当前配置（~/.claude/settings.json）一键导入 API Key。
/// cc-switch 等切换工具会把 GLM / Kimi 的 key 写进该文件的 env，
/// 这里只读 env.ANTHROPIC_BASE_URL 与 env.ANTHROPIC_AUTH_TOKEN 两个字段，
/// 按 base URL 识别 provider，其余字段（MCP、permissions 等）一概不读。
enum ClaudeConfigImporter {
    struct ImportedCredential {
        let provider: ProviderType
        let apiKey: String
    }

    static func importFromClaudeCode() -> ImportedCredential? {
        // App Sandbox 下 homeDirectoryForCurrentUser 返回的是容器路径而非真实 home，
        // 这里必须用 getpwuid 解析真实 home，才能命中 entitlements 里
        // temporary-exception.files.home-relative-path.read-only 的 /.claude/settings.json 例外。
        guard let pw = getpwuid(getuid()), let homeDir = pw.pointee.pw_dir else {
            return nil
        }
        let url = URL(fileURLWithPath: String(cString: homeDir))
            .appendingPathComponent(".claude/settings.json")
        guard let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let env = root["env"] as? [String: Any] else {
            return nil
        }

        let token = (env["ANTHROPIC_AUTH_TOKEN"] as? String) ?? (env["ANTHROPIC_API_KEY"] as? String) ?? ""
        guard !token.isEmpty else { return nil }

        let baseURL = env["ANTHROPIC_BASE_URL"] as? String ?? ""
        if baseURL.contains("bigmodel.cn") {
            return ImportedCredential(provider: .glm, apiKey: token)
        }
        if baseURL.contains("kimi.com") || baseURL.contains("moonshot") {
            return ImportedCredential(provider: .kimi, apiKey: token)
        }
        return nil
    }
}
