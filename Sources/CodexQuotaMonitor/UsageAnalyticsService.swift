import Foundation

actor UsageAnalyticsService {
    private let activityDays = 14
    private let historyDays = 14
    private let sampleBucketSeconds: TimeInterval = 300
    private let sessionsURL: URL
    private let historyURL: URL
    private var cachedActivity: LocalActivity?
    private var cachedActivityAt: Date?

    init(
        sessionsURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex")
            .appendingPathComponent("sessions"),
        historyURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex")
            .appendingPathComponent("quota-monitor")
            .appendingPathComponent("usage-history.json")
    ) {
        self.sessionsURL = sessionsURL
        self.historyURL = historyURL
    }

    func enrich(_ input: QuotaSnapshot, now: Date = Date()) -> QuotaSnapshot {
        var snapshot = input
        let activity: LocalActivity
        if let cachedActivity, let cachedActivityAt, now.timeIntervalSince(cachedActivityAt) < 300 {
            activity = cachedActivity
        } else {
            activity = readLocalActivity(now: now)
            cachedActivity = activity
            cachedActivityAt = now
        }
        snapshot.dailyTokenUsage = activity.dailyTokens

        var history = loadHistory()
        history.append(contentsOf: activity.quotaSamples)
        if !snapshot.isFallback {
            history.append(QuotaUsageSample(
                timestamp: now,
                fiveHourUsedPercent: snapshot.fiveHour?.usedPercent,
                weeklyUsedPercent: snapshot.weekly?.usedPercent
            ))
        }
        history = normalize(history, now: now)
        saveHistory(history)
        snapshot.fiveHourTrend = Self.calculateTrend(
            window: snapshot.fiveHour,
            history: history,
            useFiveHour: true,
            now: now
        )
        snapshot.weeklyTrend = Self.calculateTrend(
            window: snapshot.weekly,
            history: history,
            useFiveHour: false,
            now: now
        )
        return snapshot
    }

    nonisolated static func calculateTrend(
        window: QuotaWindow?,
        history: [QuotaUsageSample],
        useFiveHour: Bool,
        now: Date
    ) -> QuotaTrend {
        guard let window else { return QuotaTrend() }
        let cutoff = now.addingTimeInterval(-3_600)
        var values = history.compactMap { sample -> (Date, Double)? in
            guard sample.timestamp >= cutoff, sample.timestamp <= now.addingTimeInterval(60) else { return nil }
            let value = useFiveHour ? sample.fiveHourUsedPercent : sample.weeklyUsedPercent
            return value.map { (sample.timestamp, $0) }
        }.sorted { $0.0 < $1.0 }

        guard values.count >= 2 else { return QuotaTrend() }
        var afterLastReset = 0
        for index in 1..<values.count where values[index].1 + 1 < values[index - 1].1 {
            afterLastReset = index
        }
        if afterLastReset > 0 { values = Array(values.dropFirst(afterLastReset)) }
        guard values.count >= 2,
              let first = values.first,
              let last = values.last else { return QuotaTrend() }

        let elapsedHours = last.0.timeIntervalSince(first.0) / 3_600
        guard elapsedHours >= 5.0 / 60.0 else { return QuotaTrend() }
        let delta = last.1 - first.1
        let rate = min(1_000, max(0, delta <= 0.1 ? 0 : delta / elapsedHours))

        var result = QuotaTrend(hasEnoughData: true, percentPerHour: rate)
        guard rate > 0.01 else {
            result.expectedToLastUntilReset = true
            return result
        }

        let hoursToExhaust = max(0, (100 - min(100, max(0, window.usedPercent))) / rate)
        let exhaustAt = now.addingTimeInterval(hoursToExhaust * 3_600)
        result.estimatedExhaustAt = exhaustAt
        result.expectedToLastUntilReset = window.resetAt.map { exhaustAt >= $0 } ?? false
        return result
    }

    private func readLocalActivity(now: Date) -> LocalActivity {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -(activityDays - 1), to: today) else {
            return LocalActivity(dailyTokens: [], quotaSamples: [])
        }

        var totals: [Date: Int64] = [:]
        for offset in 0..<activityDays {
            if let day = calendar.date(byAdding: .day, value: offset, to: start) {
                totals[day] = 0
            }
        }
        var quotaSamples: [QuotaUsageSample] = []

        for file in sessionFiles(modifiedSince: start.addingTimeInterval(-86_400)).prefix(2_000) {
            streamLines(at: file) { line in
                guard let event = QuotaParser.parseTokenEvent(line, calendar: calendar) else { return }
                if event.day >= start, totals[event.day] != nil, event.tokens > 0 {
                    totals[event.day] = safeAdd(totals[event.day] ?? 0, event.tokens)
                }
                if let sample = event.quotaSample { quotaSamples.append(sample) }
            }
        }

        let daily = totals.keys.sorted().map { DailyTokenUsage(date: $0, tokens: totals[$0] ?? 0) }
        return LocalActivity(dailyTokens: daily, quotaSamples: quotaSamples)
    }

    private func sessionFiles(modifiedSince start: Date) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: sessionsURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var files: [(URL, Date)] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let modified = values.contentModificationDate,
                  modified >= start else { continue }
            files.append((url, modified))
        }
        return files.sorted { $0.1 < $1.1 }.map(\.0)
    }

    private func streamLines(at url: URL, body: (String) -> Void) {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }
        var buffer = Data()
        do {
            while let chunk = try handle.read(upToCount: 65_536), !chunk.isEmpty {
                buffer.append(chunk)
                while let newline = buffer.firstIndex(of: 0x0A) {
                    let lineData = buffer[..<newline]
                    if let line = String(data: lineData, encoding: .utf8), line.contains("token_count") {
                        body(line)
                    }
                    buffer.removeSubrange(...newline)
                }
            }
            if !buffer.isEmpty,
               let line = String(data: buffer, encoding: .utf8),
               line.contains("token_count") {
                body(line)
            }
        } catch {
            return
        }
    }

    private func loadHistory() -> [QuotaUsageSample] {
        guard let data = try? Data(contentsOf: historyURL),
              let history = try? JSONDecoder().decode([StoredUsageSample].self, from: data) else { return [] }
        return history.map {
            QuotaUsageSample(
                timestamp: Date(timeIntervalSince1970: $0.at),
                fiveHourUsedPercent: $0.fiveHour,
                weeklyUsedPercent: $0.weekly
            )
        }
    }

    private func saveHistory(_ history: [QuotaUsageSample]) {
        let stored = history.suffix(4_096).map {
            StoredUsageSample(
                at: $0.timestamp.timeIntervalSince1970,
                fiveHour: $0.fiveHourUsedPercent,
                weekly: $0.weeklyUsedPercent
            )
        }
        guard let data = try? JSONEncoder().encode(stored) else { return }
        do {
            try FileManager.default.createDirectory(
                at: historyURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: historyURL, options: .atomic)
        } catch {
            return
        }
    }

    private func normalize(_ history: [QuotaUsageSample], now: Date) -> [QuotaUsageSample] {
        let cutoff = now.addingTimeInterval(TimeInterval(-historyDays * 86_400))
        var buckets: [Int64: QuotaUsageSample] = [:]
        for sample in history.filter({ $0.timestamp >= cutoff }).sorted(by: { $0.timestamp < $1.timestamp }) {
            let key = Int64(sample.timestamp.timeIntervalSince1970 / sampleBucketSeconds)
            if var existing = buckets[key] {
                if let fiveHour = sample.fiveHourUsedPercent { existing.fiveHourUsedPercent = fiveHour }
                if let weekly = sample.weeklyUsedPercent { existing.weeklyUsedPercent = weekly }
                if sample.timestamp > existing.timestamp {
                    existing = QuotaUsageSample(
                        timestamp: sample.timestamp,
                        fiveHourUsedPercent: existing.fiveHourUsedPercent,
                        weeklyUsedPercent: existing.weeklyUsedPercent
                    )
                }
                buckets[key] = existing
            } else {
                buckets[key] = sample
            }
        }
        return buckets.values.sorted { $0.timestamp < $1.timestamp }
    }

    private func safeAdd(_ left: Int64, _ right: Int64) -> Int64 {
        let (sum, overflow) = left.addingReportingOverflow(right)
        return overflow ? Int64.max : sum
    }
}

private struct LocalActivity: Sendable {
    let dailyTokens: [DailyTokenUsage]
    let quotaSamples: [QuotaUsageSample]
}

private struct StoredUsageSample: Codable, Sendable {
    let at: TimeInterval
    let fiveHour: Double?
    let weekly: Double?
}
