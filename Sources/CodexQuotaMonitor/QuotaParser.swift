import Foundation

enum QuotaParser {
    static func parseAPIResponse(_ data: Data, now: Date = Date()) throws -> QuotaSnapshot {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let root = object as? [String: Any] else {
            throw MonitorError.invalidResponse
        }

        var snapshot = QuotaSnapshot()
        snapshot.planType = string(root["plan_type"])
        snapshot.updatedAt = now

        if let limits = root["rate_limit"] as? [String: Any] {
            addAPIWindow(limits["primary_window"], to: &snapshot)
            addAPIWindow(limits["secondary_window"], to: &snapshot)
        }

        if let credits = root["rate_limit_reset_credits"] as? [String: Any],
           let value = number(credits["available_count"]) {
            snapshot.resetCredits = value.intValue
        }

        if snapshot.fiveHour == nil && snapshot.weekly == nil {
            snapshot.notice = "当前账户未返回可识别的额度窗口"
        }
        return snapshot
    }

    static func parseSessionLine(_ line: String, updatedAt: Date = Date()) -> QuotaSnapshot? {
        guard line.contains("rate_limits"),
              let data = line.data(using: .utf8),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let payload = root["payload"] as? [String: Any],
              let limits = payload["rate_limits"] as? [String: Any] else {
            return nil
        }

        var snapshot = QuotaSnapshot()
        snapshot.planType = string(limits["plan_type"])
        snapshot.updatedAt = updatedAt
        addSessionWindow(limits["primary"], to: &snapshot)
        addSessionWindow(limits["secondary"], to: &snapshot)
        return snapshot.fiveHour == nil && snapshot.weekly == nil ? nil : snapshot
    }

    static func parseTokenEvent(_ line: String, calendar: Calendar = .current) -> ParsedTokenEvent? {
        guard line.contains("token_count"),
              let data = line.data(using: .utf8),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let payload = root["payload"] as? [String: Any],
              string(payload["type"]) == "token_count",
              let timestampText = string(root["timestamp"]),
              let timestamp = parseISO8601(timestampText) else {
            return nil
        }

        var tokenCount: Int64 = 0
        if let info = payload["info"] as? [String: Any],
           let last = info["last_token_usage"] as? [String: Any],
           let total = number(last["total_tokens"]) {
            tokenCount = total.int64Value
        }

        var sample = QuotaUsageSample(timestamp: timestamp)
        if let limits = payload["rate_limits"] as? [String: Any] {
            addSessionSampleWindow(limits["primary"], to: &sample)
            addSessionSampleWindow(limits["secondary"], to: &sample)
        }

        return ParsedTokenEvent(
            timestamp: timestamp,
            day: calendar.startOfDay(for: timestamp),
            tokens: max(0, tokenCount),
            quotaSample: sample.fiveHourUsedPercent == nil && sample.weeklyUsedPercent == nil ? nil : sample
        )
    }

    private static func addAPIWindow(_ value: Any?, to snapshot: inout QuotaSnapshot) {
        guard let object = value as? [String: Any],
              let seconds = number(object["limit_window_seconds"])?.int64Value,
              seconds > 0 else { return }

        let resetSeconds = number(object["reset_at"])?.doubleValue ?? 0
        let window = QuotaWindow(
            usedPercent: number(object["used_percent"])?.doubleValue ?? 0,
            windowSeconds: seconds,
            resetAt: resetSeconds > 0 ? Date(timeIntervalSince1970: resetSeconds) : nil
        )
        classify(window, into: &snapshot)
    }

    private static func addSessionWindow(_ value: Any?, to snapshot: inout QuotaSnapshot) {
        guard let object = value as? [String: Any],
              let minutes = number(object["window_minutes"])?.int64Value,
              minutes > 0 else { return }

        let resetSeconds = number(object["resets_at"] ?? object["reset_at"])?.doubleValue ?? 0
        let window = QuotaWindow(
            usedPercent: number(object["used_percent"])?.doubleValue ?? 0,
            windowSeconds: minutes * 60,
            resetAt: resetSeconds > 0 ? Date(timeIntervalSince1970: resetSeconds) : nil
        )
        classify(window, into: &snapshot)
    }

    private static func addSessionSampleWindow(_ value: Any?, to sample: inout QuotaUsageSample) {
        guard let object = value as? [String: Any],
              let minutes = number(object["window_minutes"])?.int64Value else { return }
        let used = number(object["used_percent"])?.doubleValue ?? 0
        if (180...360).contains(minutes) {
            sample.fiveHourUsedPercent = used
        } else if (7_200...12_960).contains(minutes) {
            sample.weeklyUsedPercent = used
        }
    }

    private static func classify(_ window: QuotaWindow, into snapshot: inout QuotaSnapshot) {
        if (3 * 60 * 60...6 * 60 * 60).contains(window.windowSeconds) {
            snapshot.fiveHour = window
        } else if (5 * 24 * 60 * 60...9 * 24 * 60 * 60).contains(window.windowSeconds) {
            snapshot.weekly = window
        }
    }

    private static func number(_ value: Any?) -> NSNumber? {
        if let number = value as? NSNumber { return number }
        if let text = value as? String, let double = Double(text) { return NSNumber(value: double) }
        return nil
    }

    private static func string(_ value: Any?) -> String? {
        value as? String
    }

    private static func parseISO8601(_ text: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: text) { return date }
        return ISO8601DateFormatter().date(from: text)
    }
}

struct ParsedTokenEvent: Sendable {
    let timestamp: Date
    let day: Date
    let tokens: Int64
    let quotaSample: QuotaUsageSample?
}
