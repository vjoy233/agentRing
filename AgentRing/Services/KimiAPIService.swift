//
//  KimiAPIService.swift
//  Agent Ring
//

import Foundation
import OSLog

/// Kimi Coding Plan 用量服务（Moonshot）
/// 数据源：GET https://api.kimi.com/coding/v1/usages（Bearer sk-kimi-* API Key）
class KimiAPIService: UsageProvider {
    var providerType: ProviderType { .kimi }

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

    func fetchUsage(completion: @escaping (Result<KimiUsageData, Error>) -> Void) {
        #if DEBUG
        if settings.debugModeEnabled {
            DispatchQueue.main.async { completion(.success(self.createMockData())) }
            return
        }
        #endif

        cancelAllRequests()

        guard settings.hasValidKimiCredentials else {
            completion(.failure(UsageError.noCredentials))
            return
        }

        fetchUsages(apiKey: settings.kimiApiKey, completion: completion)
    }

    /// 添加账号时「粘贴即验证」：直接拉一次用量端点验证 Key 有效性
    func validateApiKey(_ apiKey: String, completion: @escaping (Result<KimiUsageData, Error>) -> Void) {
        fetchUsages(apiKey: apiKey, completion: completion)
    }

    private func fetchUsages(apiKey: String, completion: @escaping (Result<KimiUsageData, Error>) -> Void) {
        guard let url = URL(string: "https://api.kimi.com/coding/v1/usages") else {
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
                let decoded = try JSONDecoder().decode(KimiUsageResponse.self, from: data)
                let usage = decoded.toUsageData()
                if usage.primary == nil && usage.secondary == nil {
                    Logger.api.error("Kimi usages 响应无可识别窗口")
                    DispatchQueue.main.async { completion(.failure(UsageError.noData)) }
                    return
                }
                DispatchQueue.main.async { completion(.success(usage)) }
            } catch {
                Logger.api.error("Kimi usages 解码失败: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(.failure(UsageError.decodingError)) }
            }
        }
        activeTasks.append(task)
        task.resume()
    }

    #if DEBUG
    private func createMockData() -> KimiUsageData {
        KimiUsageData(
            primary: .init(percentage: 7, resetsAt: Date().addingTimeInterval(3 * 3600)),
            secondary: .init(percentage: 59, resetsAt: Date().addingTimeInterval(2 * 24 * 3600)),
            userId: "mock-kimi-user"
        )
    }
    #endif
}
