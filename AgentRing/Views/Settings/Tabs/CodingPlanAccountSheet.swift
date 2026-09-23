//
//  CodingPlanAccountSheet.swift
//  Agent Ring
//

import SwiftUI

/// GLM / Kimi Coding Plan 添加账号弹窗：粘贴即验证，
/// 验证失败标红提示但允许保存（A2），支持从 Claude Code 当前配置一键导入（D1）。
struct CodingPlanAccountSheet: View {
    let provider: ProviderType
    let onAdd: (Account) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = ""
    @State private var isValidating = false
    @State private var validationError: String?
    @State private var importHint: String?

    private var trimmedKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(format: L.CodingPlan.addTitle, provider.displayName))
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text(L.CodingPlan.apiKeyField)
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField(L.CodingPlan.apiKeyPlaceholder, text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .disabled(isValidating)
            }

            Button {
                importFromClaudeCode()
            } label: {
                Label(L.CodingPlan.importFromClaude, systemImage: "square.and.arrow.down.on.square")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .disabled(isValidating)

            if let importHint {
                Text(importHint)
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            if let validationError {
                Text(validationError)
                    .font(.caption)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button(L.Account.cancel, role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                if validationError != nil {
                    Button(L.CodingPlan.saveAnyway) {
                        onAdd(Self.fallbackAccount(provider: provider, apiKey: trimmedKey))
                        dismiss()
                    }
                    .disabled(trimmedKey.isEmpty || isValidating)
                }

                Button {
                    validateAndAdd()
                } label: {
                    if isValidating {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(L.Account.validateAndAdd)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(trimmedKey.isEmpty || isValidating)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    // MARK: - Actions

    private func importFromClaudeCode() {
        guard let imported = ClaudeConfigImporter.importFromClaudeCode() else {
            importHint = L.CodingPlan.importMismatch
            return
        }
        guard imported.provider == provider else {
            importHint = String(format: L.CodingPlan.importProviderMismatch, imported.provider.displayName)
            return
        }
        apiKey = imported.apiKey
        importHint = nil
        validationError = nil
    }

    private func validateAndAdd() {
        let key = trimmedKey
        guard !key.isEmpty else {
            validationError = L.CodingPlan.emptyKey
            return
        }
        isValidating = true
        validationError = nil

        if provider == .glm {
            GlmAPIService().validateApiKey(key) { result in
                handleValidation(result: result.map { .glm($0) }, key: key)
            }
        } else {
            KimiAPIService().validateApiKey(key) { result in
                handleValidation(result: result.map { .kimi($0) }, key: key)
            }
        }
    }

    private enum ValidatedUsage {
        case glm(GlmUsageData)
        case kimi(KimiUsageData)
    }

    private func handleValidation(result: Result<ValidatedUsage, Error>, key: String) {
        DispatchQueue.main.async {
            isValidating = false
            switch result {
            case .success(let usage):
                onAdd(Self.account(provider: provider, apiKey: key, usage: usage))
                dismiss()
            case .failure(let error):
                validationError = error.localizedDescription
            }
        }
    }

    // MARK: - Account 构建

    /// 验证成功：GLM 用档位、Kimi 用 userId 尾号做账号标识与默认名
    static func account(provider: ProviderType, apiKey: String, usage: ValidatedUsage) -> Account {
        let fingerprint = String(apiKey.prefix(8))
        switch usage {
        case .glm(let data):
            let identifier = "glm-\(fingerprint)"
            let name = data.planLevel.map { "GLM (\($0))" } ?? "GLM"
            return Account(
                credentialToken: apiKey,
                accountIdentifier: identifier,
                accountName: name,
                provider: .glm
            )
        case .kimi(let data):
            let identifier = data.userId ?? "kimi-\(fingerprint)"
            let name = data.userId.map { "Kimi (\(String($0.suffix(6))))" } ?? "Kimi"
            return Account(
                credentialToken: apiKey,
                accountIdentifier: identifier,
                accountName: name,
                provider: .kimi
            )
        }
    }

    /// 验证失败仍要保存：key 指纹做标识，坏 key 由刷新时的失效态暴露
    static func fallbackAccount(provider: ProviderType, apiKey: String) -> Account {
        Account(
            credentialToken: apiKey,
            accountIdentifier: "\(provider.rawValue)-\(String(apiKey.prefix(8)))",
            accountName: provider.displayName,
            provider: provider
        )
    }
}
