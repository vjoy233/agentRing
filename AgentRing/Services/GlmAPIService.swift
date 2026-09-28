//
//  GlmAPIService.swift
//  Agent Ring
//

import Foundation
import OSLog

/// 智谱 GLM Coding Plan 用量服务
/// 数据源：GET https://bigmodel.cn/api/monitor/usage/quota/limit（Bearer API Key）。
/// 注意：/api/anthropic 消息端点的响应头不含配额信息，配额只在这个监控端点上。
class GlmAPIService: UsageProvider {
    var providerType: ProviderType { .glm }

    private let settings = UserSettings.shared
    private let session: URLSession
    private var activeTasks: [URLSessionDataTask] = []

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: configuration)
    }

    func cancelAllRequests() {
        activeTasks.forEach { $0.cancel() }
        activeTasks.removeAll()
    }

    func fetchUsage(completion: @escaping (Result<GlmUsageData, Error>) -> Void) {
        #if DEBUG
        if settings.debugModeEnabled {
            DispatchQueue.main.async { completion(.success(self.createMockData())) }
            return
        }
        #endif

        cancelAllRequests()

        guard settings.hasValidGlmCredentials else {
            DispatchQueue.main.async { completion(.failure(UsageError.noCredentials)) }
            return
        }

        fetchQuotaLimit(apiKey: settings.glmApiKey, completion: completion)
    }

    /// 添加账号时「粘贴即验证」：直接拉一次配额端点验证 Key 有效性
    func validateApiKey(_ apiKey: String, completion: @escaping (Result<GlmUsageData, Error>) -> Void) {
        fetchQuotaLimit(apiKey: apiKey, completion: completion)
    }

    private func fetchQuotaLimit(apiKey: String, completion: @escaping (Result<GlmUsageData, Error>) -> Void) {
        guard let url = URL(string: "https://bigmodel.cn/api/monitor/usage/quota/limit") else {
            completion(.failure(UsageError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "authorization")

        let task = session.dataTask(with: request) { data, response, error in
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let http = response as? HTTPURLResponse else {
                DispatchQueue.main.async { completion(.failure(UsageError.networkError)) }
                return
            }
            if http.statusCode == 401 || http.statusCode == 403 {
                DispatchQueue.main.async { completion(.failure(UsageError.unauthorized)) }
                return
            }
            if http.statusCode == 429 {
                DispatchQueue.main.async { completion(.failure(UsageError.rateLimited)) }
                return
            }
            guard (200...299).contains(http.statusCode), let data, !data.isEmpty else {
                DispatchQueue.main.async { completion(.failure(UsageError.httpError(statusCode: http.statusCode))) }
                return
            }
            do {
                let decoded = try JSONDecoder().decode(GlmUsageResponse.self, from: data)
                if decoded.isErrorPayload {
                    let code = decoded.code ?? http.statusCode
                    let error: UsageError = code == 401 ? .unauthorized : .httpError(statusCode: code)
                    DispatchQueue.main.async { completion(.failure(error)) }
                    return
                }
                let usage = decoded.toUsageData()
                DispatchQueue.main.async { completion(.success(usage)) }
            } catch {
                Logger.api.error("GLM quota/limit 解码失败: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(.failure(UsageError.decodingError)) }
            }
        }
        activeTasks.append(task)
        task.resume()
    }

    #if DEBUG
    private func createMockData() -> GlmUsageData {
        GlmUsageData(
            primary: .init(percentage: 34, resetsAt: Date().addingTimeInterval(3 * 3600)),
            secondary: .init(percentage: 61, resetsAt: Date().addingTimeInterval(4 * 24 * 3600)),
            planLevel: "max"
        )
    }
    #endif
}
