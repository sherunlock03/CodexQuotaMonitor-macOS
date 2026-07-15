import Foundation
import SwiftUI

@MainActor
final class QuotaStore: ObservableObject {
    @Published private(set) var snapshot: QuotaSnapshot?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isRefreshing = false

    private let quotaService: QuotaService
    private let analytics: UsageAnalyticsService
    private var refreshLoop: Task<Void, Never>?

    init(
        quotaService: QuotaService = QuotaService(),
        analytics: UsageAnalyticsService = UsageAnalyticsService()
    ) {
        self.quotaService = quotaService
        self.analytics = analytics
    }

    var menuBarTitle: String {
        guard let snapshot else { return "Codex --" }
        let fiveHour = snapshot.fiveHour.map { "5h \(Int($0.remainingPercent.rounded()))%" }
        let weekly = snapshot.weekly.map { "周 \(Int($0.remainingPercent.rounded()))%" }
        let title = [fiveHour, weekly].compactMap { $0 }.joined(separator: " · ")
        return title.isEmpty ? "Codex --" : title
    }

    func start() {
        guard refreshLoop == nil else { return }
        refreshLoop = Task { [weak self] in
            guard let self else { return }
            await refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(90))
                if Task.isCancelled { break }
                await refresh()
            }
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        errorMessage = nil
        defer { isRefreshing = false }
        do {
            let fresh = try await quotaService.fetch()
            snapshot = await analytics.enrich(fresh)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
