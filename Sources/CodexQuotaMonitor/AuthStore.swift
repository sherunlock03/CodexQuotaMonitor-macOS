import Foundation

struct AuthCredentials: Sendable {
    let accessToken: String
    let accountID: String?
}

struct AuthStore: Sendable {
    let authURL: URL

    init(authURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".codex")
        .appendingPathComponent("auth.json")) {
        self.authURL = authURL
    }

    func load() throws -> AuthCredentials {
        guard FileManager.default.fileExists(atPath: authURL.path) else {
            throw MonitorError.authFileMissing
        }

        let data = try Data(contentsOf: authURL)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MonitorError.invalidCredentials
        }
        let tokens = root["tokens"] as? [String: Any]
        let accessToken = (tokens?["access_token"] as? String) ?? (root["access_token"] as? String)
        let accountID = (tokens?["account_id"] as? String) ?? (root["account_id"] as? String)

        guard let accessToken, !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MonitorError.invalidCredentials
        }
        return AuthCredentials(accessToken: accessToken, accountID: accountID)
    }
}
