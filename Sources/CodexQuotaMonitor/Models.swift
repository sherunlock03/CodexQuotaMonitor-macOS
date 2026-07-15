import Foundation

struct QuotaWindow: Equatable, Sendable {
    let usedPercent: Double
    let windowSeconds: Int64
    let resetAt: Date?

    var remainingPercent: Double {
        min(100, max(0, 100 - usedPercent))
    }
}

struct DailyTokenUsage: Equatable, Identifiable, Sendable {
    let date: Date
    let tokens: Int64

    var id: Date { date }
}

struct QuotaUsageSample: Codable, Equatable, Sendable {
    let timestamp: Date
    var fiveHourUsedPercent: Double? = nil
    var weeklyUsedPercent: Double? = nil
}

struct QuotaTrend: Equatable, Sendable {
    var hasEnoughData = false
    var percentPerHour = 0.0
    var estimatedExhaustAt: Date?
    var expectedToLastUntilReset = false
}

struct QuotaSnapshot: Sendable {
    var fiveHour: QuotaWindow?
    var weekly: QuotaWindow?
    var resetCredits: Int?
    var planType: String?
    var updatedAt = Date()
    var isFallback = false
    var notice: String?
    var dailyTokenUsage: [DailyTokenUsage] = []
    var fiveHourTrend = QuotaTrend()
    var weeklyTrend = QuotaTrend()
}

enum MonitorError: LocalizedError, Sendable {
    case authFileMissing
    case invalidCredentials
    case invalidResponse
    case serverStatus(Int)
    case message(String)

    var errorDescription: String? {
        switch self {
        case .authFileMissing:
            return "未找到 Codex 登录信息，请先在 Codex App 或 CLI 中登录。"
        case .invalidCredentials:
            return "Codex 登录令牌不可用，请重新登录 Codex。"
        case .invalidResponse:
            return "额度服务返回了无法识别的数据。"
        case .serverStatus(let status):
            return "额度服务返回 HTTP \(status)，请确认 Codex 已登录。"
        case .message(let value):
            return value
        }
    }
}
