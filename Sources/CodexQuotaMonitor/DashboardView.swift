import AppKit
import SwiftUI

private enum QuotaScale {
    static let warningBoundary = 30.0
    static let healthyBoundary = 75.0
    static let boundaries = [warningBoundary, healthyBoundary]
}

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

    var quotaSeparator: Color {
        self == .dark
            ? Color.white.opacity(0.72)
            : Color.black.opacity(0.55)
    }

    func quotaAccent(remaining: Double?) -> Color {
        guard let remaining else { return mutedText }
        if remaining > QuotaScale.healthyBoundary {
            return self == .dark
                ? Color(red: 0.29, green: 0.87, blue: 0.50)
                : Color(red: 0.05, green: 0.43, blue: 0.20)
        }
        if remaining >= QuotaScale.warningBoundary {
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
    @State private var isRefreshControlHovered = false

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
            ThemeToggle(themeRawValue: $themeRawValue, theme: theme)

            Button {
                isRefreshControlHovered = false
                NSCursor.arrow.set()
                Task { await store.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(isRefreshControlHovered ? theme.primaryText : theme.accentBlue)
                    .frame(width: 28, height: 28)
                    .background(
                        isRefreshControlHovered
                            ? theme.accentBlue.opacity(theme == .dark ? 0.28 : 0.16)
                            : theme.track.opacity(theme == .dark ? 0.34 : 0.48),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(
                                isRefreshControlHovered
                                    ? theme.accentBlue.opacity(0.58)
                                    : theme.cardBorder.opacity(0.65),
                                lineWidth: 1
                            )
                    )
                    .scaleEffect(isRefreshControlHovered ? 1.07 : 1)
                    .offset(y: isRefreshControlHovered ? -1 : 0)
                    .animation(.easeOut(duration: 0.12), value: isRefreshControlHovered)
                    .rotationEffect(store.isRefreshing ? .degrees(360) : .zero)
                    .animation(store.isRefreshing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: store.isRefreshing)
            }
            .buttonStyle(PressScaleButtonStyle())
            .disabled(store.isRefreshing)
            .help("立即刷新")
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    if !store.isRefreshing {
                        isRefreshControlHovered = true
                        NSCursor.pointingHand.set()
                    }
                case .ended:
                    isRefreshControlHovered = false
                    NSCursor.arrow.set()
                }
            }
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
            .buttonStyle(HoverTextButtonStyle(theme: theme, tint: theme.accentBlue))
            .help("打开 Codex 用量网页")
            Button("退出") { NSApplication.shared.terminate(nil) }
                .buttonStyle(HoverTextButtonStyle(theme: theme, tint: theme.warning))
                .help("退出额度监视器")
        }
    }
}

private struct ThemeToggle: View {
    @Binding var themeRawValue: String
    let theme: MonitorTheme
    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(theme.track.opacity(theme == .dark ? 0.62 : 0.78))

            Capsule()
                .fill(theme.accentBlue.gradient)
                .frame(width: 28, height: 24)
                .offset(x: theme == .light ? 3 : 33)
                .shadow(color: theme.accentBlue.opacity(0.32), radius: 3, y: 1)

            HStack(spacing: 0) {
                themeButton(.light, icon: "sun.max.fill", help: "切换到浅色模式")
                themeButton(.dark, icon: "moon.fill", help: "切换到深色模式")
            }
        }
        .frame(width: 64, height: 30)
        .overlay(
            Capsule()
                .stroke(
                    isHovered ? theme.accentBlue.opacity(0.70) : theme.cardBorder.opacity(0.72),
                    lineWidth: isHovered ? 1.5 : 1
                )
        )
        .shadow(
            color: isHovered ? theme.accentBlue.opacity(theme == .dark ? 0.28 : 0.18) : Color.clear,
            radius: 5,
            y: 1
        )
        .scaleEffect(isHovered ? 1.06 : 1)
        .offset(y: isHovered ? -1 : 0)
        .contentShape(Capsule())
        .animation(.spring(response: 0.22, dampingFraction: 0.78), value: theme)
        .animation(.easeOut(duration: 0.14), value: isHovered)
        .onContinuousHover { phase in
            switch phase {
            case .active:
                isHovered = true
                NSCursor.pointingHand.set()
            case .ended:
                isHovered = false
                NSCursor.arrow.set()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("外观模式")
    }

    private func themeButton(_ target: MonitorTheme, icon: String, help: String) -> some View {
        Button {
            themeRawValue = target.rawValue
        } label: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme == target ? Color.white : theme.mutedText)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(ThemeSegmentButtonStyle())
        .help(help)
        .accessibilityLabel(target == .light ? "浅色模式" : "深色模式")
        .accessibilityValue(theme == target ? "已选择" : "未选择")
    }
}

private struct ThemeSegmentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.82 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

private struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

private struct HoverTextButtonStyle: ButtonStyle {
    let theme: MonitorTheme
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        HoverTextButtonBody(configuration: configuration, theme: theme, tint: tint)
    }
}

private struct HoverTextButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let theme: MonitorTheme
    let tint: Color
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .font(.caption.weight(isHovered ? .semibold : .medium))
            .foregroundStyle(isHovered ? tint : theme.secondaryText)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                isHovered
                    ? tint.opacity(theme == .dark ? 0.28 : 0.17)
                    : Color.primary.opacity(0.001),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(isHovered ? tint.opacity(0.62) : Color.clear, lineWidth: 1)
            )
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.95 : (isHovered ? 1.05 : 1))
            .offset(y: isHovered && !configuration.isPressed ? -1 : 0)
            .animation(.easeOut(duration: 0.14), value: isHovered)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    isHovered = true
                    NSCursor.pointingHand.set()
                case .ended:
                    isHovered = false
                    NSCursor.arrow.set()
                }
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
                    ForEach(QuotaScale.boundaries, id: \.self) { boundary in
                        Rectangle()
                            .fill(theme.quotaSeparator)
                            .frame(width: 1.5, height: proxy.size.height)
                            .position(
                                x: proxy.size.width * CGFloat(boundary / 100),
                                y: proxy.size.height / 2
                            )
                            .allowsHitTesting(false)
                    }
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
    @State private var hoveredUsageID: DailyTokenUsage.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("最近 14 天 Token", systemImage: "chart.bar.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                Spacer()
                Text(summaryText)
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(theme.secondaryText)
            }
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(values) { item in
                    ZStack(alignment: .bottom) {
                        // A nearly transparent fill keeps the entire column in AppKit's
                        // mouse-tracking region, including days with a very short bar.
                        Rectangle().fill(Color.primary.opacity(0.001))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(item.id == activeUsageID
                                ? theme.accentBlue
                                : theme.accentBlue.opacity(hoveredUsageID == nil ? 0.48 : 0.24))
                            .frame(height: barHeight(item.tokens))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 72)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active:
                            hoveredUsageID = item.id
                        case .ended:
                            if hoveredUsageID == item.id {
                                hoveredUsageID = nil
                            }
                        }
                    }
                    .help(tooltipText(for: item))
                    .accessibilityLabel(tooltipText(for: item))
                }
            }
            .frame(height: 72, alignment: .bottom)
            .animation(.easeOut(duration: 0.12), value: hoveredUsageID)
        }
        .padding(13)
        .background(MonitorCardBackground(theme: theme))
    }

    private var maximum: Int64 { max(1, values.map(\.tokens).max() ?? 1) }

    private var activeUsageID: DailyTokenUsage.ID? {
        hoveredUsageID ?? values.last?.id
    }

    private var selectedUsage: DailyTokenUsage? {
        guard let activeUsageID else { return values.last }
        return values.first { $0.id == activeUsageID } ?? values.last
    }

    private var summaryText: String {
        guard let selectedUsage else { return "--" }
        return "\(dateLabel(selectedUsage.date)) · \(compactTokens(selectedUsage.tokens))"
    }

    private func barHeight(_ tokens: Int64) -> CGFloat {
        max(3, CGFloat(Double(tokens) / Double(maximum)) * 72)
    }

    private func dateLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "今天" }
        if calendar.isDateInYesterday(date) { return "昨天" }
        return date.formatted(.dateTime.month().day())
    }

    private func compactTokens(_ value: Int64) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM", Double(value) / 1_000_000) }
        if value >= 1_000 { return String(format: "%.1fK", Double(value) / 1_000) }
        return value.formatted()
    }

    private func tooltipText(for item: DailyTokenUsage) -> String {
        "\(item.date.formatted(date: .long, time: .omitted))：\(item.tokens.formatted()) tokens"
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
