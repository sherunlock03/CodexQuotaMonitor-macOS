import AppKit
import SwiftUI

private enum MonitorTheme: String {
    case dark
    case light

    var colorScheme: ColorScheme { self == .dark ? .dark : .light }
    var title: String { self == .dark ? "深色" : "浅色" }
    var icon: String { self == .dark ? "moon.fill" : "sun.max.fill" }

    var backgroundTop: Color {
        self == .dark
            ? Color(red: 0.055, green: 0.075, blue: 0.12)
            : Color(red: 0.965, green: 0.978, blue: 1.0)
    }

    var backgroundBottom: Color {
        self == .dark
            ? Color(red: 0.025, green: 0.035, blue: 0.06)
            : Color(red: 0.89, green: 0.93, blue: 0.98)
    }

    var cardFill: Color {
        self == .dark
            ? Color(red: 0.105, green: 0.13, blue: 0.19)
            : Color.white
    }

    var cardBorder: Color {
        self == .dark
            ? Color(red: 0.28, green: 0.34, blue: 0.44)
            : Color(red: 0.70, green: 0.76, blue: 0.84)
    }

    var primaryText: Color {
        self == .dark
            ? Color(red: 0.96, green: 0.97, blue: 0.99)
            : Color(red: 0.06, green: 0.09, blue: 0.14)
    }

    var secondaryText: Color {
        self == .dark
            ? Color(red: 0.78, green: 0.82, blue: 0.88)
            : Color(red: 0.25, green: 0.32, blue: 0.42)
    }

    var mutedText: Color {
        self == .dark
            ? Color(red: 0.66, green: 0.72, blue: 0.80)
            : Color(red: 0.35, green: 0.43, blue: 0.54)
    }

    var track: Color {
        self == .dark
            ? Color(red: 0.24, green: 0.28, blue: 0.36)
            : Color(red: 0.82, green: 0.86, blue: 0.91)
    }

    var accentBlue: Color {
        self == .dark
            ? Color(red: 0.38, green: 0.65, blue: 0.98)
            : Color(red: 0.10, green: 0.32, blue: 0.72)
    }

    var warning: Color {
        self == .dark
            ? Color(red: 0.98, green: 0.60, blue: 0.28)
            : Color(red: 0.65, green: 0.28, blue: 0.02)
    }

    func quotaAccent(remaining: Double?) -> Color {
        guard let remaining else { return mutedText }
        if remaining > 75 {
            return self == .dark
                ? Color(red: 0.29, green: 0.87, blue: 0.50)
                : Color(red: 0.05, green: 0.43, blue: 0.20)
        }
        if remaining >= 30 {
            return self == .dark
                ? Color(red: 0.99, green: 0.69, blue: 0.32)
                : Color(red: 0.64, green: 0.27, blue: 0.01)
        }
        return self == .dark
            ? Color(red: 0.98, green: 0.39, blue: 0.44)
            : Color(red: 0.69, green: 0.06, blue: 0.10)
    }
}

struct DashboardView: View {
    @ObservedObject var store: QuotaStore
    @AppStorage("monitorTheme") private var themeRawValue = MonitorTheme.dark.rawValue

    private var theme: MonitorTheme {
        MonitorTheme(rawValue: themeRawValue) ?? .dark
    }

    var body: some View {
        VStack(spacing: 14) {
            header

            if let snapshot = store.snapshot {
                QuotaCard(title: "5 小时额度", window: snapshot.fiveHour, icon: "clock", theme: theme)
                QuotaCard(title: "每周额度", window: snapshot.weekly, icon: "calendar", theme: theme)
                resetCredits(snapshot)

                if snapshot.fiveHourTrend.hasEnoughData || snapshot.weeklyTrend.hasEnoughData {
                    TrendSection(snapshot: snapshot, theme: theme)
                }
                if !snapshot.dailyTokenUsage.isEmpty {
                    TokenActivityChart(values: snapshot.dailyTokenUsage, theme: theme)
                }
                if let notice = snapshot.notice {
                    NoticeRow(text: notice, isWarning: snapshot.isFallback, theme: theme)
                }
            } else if store.errorMessage == nil {
                loadingState
            }

            if let errorMessage = store.errorMessage {
                errorState(errorMessage)
            }

            footer
        }
        .padding(16)
        .frame(width: 390)
        .foregroundStyle(theme.primaryText)
        .tint(theme.accentBlue)
        .background(
            LinearGradient(
                colors: [theme.backgroundTop, theme.backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .preferredColorScheme(theme.colorScheme)
        .task { store.start() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(theme.accentBlue)
                .frame(width: 32, height: 32)
                .background(theme.accentBlue.opacity(theme == .dark ? 0.20 : 0.12), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("Codex 额度")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(theme.primaryText)
                    if let plan = store.snapshot?.planType, !plan.isEmpty {
                        Text(plan.uppercased())
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(theme.secondaryText)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(theme.accentBlue.opacity(0.11), in: Capsule())
                    }
                }
                Text("每 90 秒自动刷新")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }
            Spacer(minLength: 6)
            Menu {
                Button {
                    themeRawValue = MonitorTheme.dark.rawValue
                } label: {
                    Label("深色", systemImage: theme == .dark ? "checkmark.circle.fill" : "moon.fill")
                }
                Button {
                    themeRawValue = MonitorTheme.light.rawValue
                } label: {
                    Label("浅色", systemImage: theme == .light ? "checkmark.circle.fill" : "sun.max.fill")
                }
            } label: {
                Label(theme.title, systemImage: theme.icon)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(theme.primaryText)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("切换深色或浅色外观")

            Button {
                Task { await store.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(theme.accentBlue)
                    .rotationEffect(store.isRefreshing ? .degrees(360) : .zero)
                    .animation(store.isRefreshing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: store.isRefreshing)
            }
            .buttonStyle(.borderless)
            .disabled(store.isRefreshing)
            .help("立即刷新")
        }
    }

    private func resetCredits(_ snapshot: QuotaSnapshot) -> some View {
        HStack {
            Label("剩余重置次数", systemImage: "arrow.triangle.2.circlepath")
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
            Spacer()
            Text(snapshot.resetCredits.map(String.init) ?? "--")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(theme.primaryText)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(MonitorCardBackground(theme: theme))
    }

    private var loadingState: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text("正在读取 Codex 额度…").foregroundStyle(theme.secondaryText)
            Spacer()
        }
        .padding(14)
        .background(MonitorCardBackground(theme: theme))
    }

    private func errorState(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("暂时无法读取额度", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(theme.warning)
            Text(message)
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Button("重新尝试") { Task { await store.refresh() } }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(MonitorCardBackground(theme: theme))
    }

    private var footer: some View {
        HStack {
            if let updatedAt = store.snapshot?.updatedAt {
                Text("更新于 \(updatedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(theme.mutedText)
            } else {
                Text("令牌仅在内存中读取")
                    .font(.caption2)
                    .foregroundStyle(theme.mutedText)
            }
            Spacer()
            Button("用量网页") {
                if let url = URL(string: "https://chatgpt.com/codex/settings/usage") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.link)
            .font(.caption)
            Button("退出") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.link)
                .font(.caption)
        }
    }
}

private struct MonitorCardBackground: View {
    let theme: MonitorTheme

    var body: some View {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(theme.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(theme.cardBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(theme == .dark ? 0.20 : 0.08), radius: 5, y: 2)
    }
}

private struct QuotaCard: View {
    let title: String
    let window: QuotaWindow?
    let icon: String
    let theme: MonitorTheme

    var body: some View {
        VStack(spacing: 11) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.secondaryText)
                Spacer()
                Text(window.map { "\(Int($0.remainingPercent.rounded()))%" } ?? "--")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.track)
                    Capsule()
                        .fill(accent.gradient)
                        .frame(width: proxy.size.width * CGFloat((window?.remainingPercent ?? 0) / 100))
                }
            }
            .frame(height: 8)
            HStack {
                Text(window == nil ? "暂无数据" : "剩余额度")
                Spacer()
                if let resetAt = window?.resetAt {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text("\(countdown(to: resetAt, from: context.date)) 后重置")
                            .monospacedDigit()
                    }
                }
            }
            .font(.caption)
            .foregroundStyle(theme.mutedText)
        }
        .padding(13)
        .background(MonitorCardBackground(theme: theme))
    }

    private var accent: Color {
        theme.quotaAccent(remaining: window?.remainingPercent)
    }

    private func countdown(to target: Date, from now: Date) -> String {
        let seconds = max(0, Int(target.timeIntervalSince(now)))
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        let remainingSeconds = seconds % 60
        if days > 0 { return "\(days)天 \(hours)小时" }
        if hours > 0 { return String(format: "%02d:%02d:%02d", hours, minutes, remainingSeconds) }
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

private struct TrendSection: View {
    let snapshot: QuotaSnapshot
    let theme: MonitorTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("近 1 小时消耗", systemImage: "chart.line.uptrend.xyaxis")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.primaryText)
            if snapshot.fiveHourTrend.hasEnoughData {
                trendRow("5 小时", snapshot.fiveHourTrend)
            }
            if snapshot.weeklyTrend.hasEnoughData {
                trendRow("每周", snapshot.weeklyTrend)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(MonitorCardBackground(theme: theme))
    }

    private func trendRow(_ label: String, _ trend: QuotaTrend) -> some View {
        HStack {
            Text(label).foregroundStyle(theme.secondaryText)
            Spacer()
            Text(String(format: "%.1f%% / 小时", trend.percentPerHour))
                .foregroundStyle(theme.primaryText)
                .monospacedDigit()
            if trend.expectedToLastUntilReset {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(theme.quotaAccent(remaining: 100))
            } else {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(theme.warning)
            }
        }
        .font(.caption)
    }
}

private struct TokenActivityChart: View {
    let values: [DailyTokenUsage]
    let theme: MonitorTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("最近 14 天 Token", systemImage: "chart.bar.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                Spacer()
                Text(compact(values.last?.tokens ?? 0))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(theme.secondaryText)
            }
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(values) { item in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(item.id == values.last?.id ? theme.accentBlue : theme.accentBlue.opacity(0.48))
                        .frame(height: barHeight(item.tokens))
                        .help("\(item.date.formatted(date: .abbreviated, time: .omitted))：\(item.tokens.formatted()) tokens")
                }
            }
            .frame(height: 72, alignment: .bottom)
        }
        .padding(13)
        .background(MonitorCardBackground(theme: theme))
    }

    private var maximum: Int64 { max(1, values.map(\.tokens).max() ?? 1) }

    private func barHeight(_ tokens: Int64) -> CGFloat {
        max(3, CGFloat(Double(tokens) / Double(maximum)) * 72)
    }

    private func compact(_ value: Int64) -> String {
        if value >= 1_000_000 { return String(format: "今日 %.1fM", Double(value) / 1_000_000) }
        if value >= 1_000 { return String(format: "今日 %.1fK", Double(value) / 1_000) }
        return "今日 \(value)"
    }
}

private struct NoticeRow: View {
    let text: String
    let isWarning: Bool
    let theme: MonitorTheme

    var body: some View {
        Label(text, systemImage: isWarning ? "wifi.slash" : "info.circle")
            .font(.caption)
            .foregroundStyle(isWarning ? theme.warning : theme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
