import Foundation

struct QuotaService: Sendable {
    static let usageEndpoint = URL(string: "https://chatgpt.com/backend-api/wham/usage")!

    let authStore: AuthStore
    let fallback: SessionFallback
    let session: URLSession

    init(
        authStore: AuthStore = AuthStore(),
        fallback: SessionFallback = SessionFallback(),
        session: URLSession = .shared
    ) {
        self.authStore = authStore
        self.fallback = fallback
        self.session = session
    }

    func fetch() async throws -> QuotaSnapshot {
        do {
            let credentials = try authStore.load()
            var request = URLRequest(url: Self.usageEndpoint)
            request.timeoutInterval = 12
            request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("CodexQuotaMonitor/1.0 (macOS)", forHTTPHeaderField: "User-Agent")
            if let accountID = credentials.accountID, !accountID.isEmpty {
                request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
            }

            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw MonitorError.invalidResponse
            }
            guard (200..<300).contains(http.statusCode) else {
                throw MonitorError.serverStatus(http.statusCode)
            }
            return try QuotaParser.parseAPIResponse(data)
        } catch {
            if var cached = await Task.detached(priority: .utility, operation: fallback.latestSnapshot).value {
                cached.isFallback = true
                cached.notice = "网络更新失败，显示 Codex 最近一次本地记录"
                return cached
            }
            if let monitorError = error as? MonitorError { throw monitorError }
            if let urlError = error as? URLError {
                throw MonitorError.message("无法连接额度服务：\(urlError.localizedDescription)")
            }
            throw MonitorError.message(error.localizedDescription)
        }
    }
}
