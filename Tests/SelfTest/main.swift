import Foundation

private var failures = 0

private func check(_ condition: @autoclosure () -> Bool, _ name: String) {
    if condition() {
        print("  ok  \(name)")
    } else {
        failures += 1
        fputs("  no  \(name)\n", stderr)
    }
}

private func parserChecks() throws {
    let bothWindows = #"{"plan_type":"plus","rate_limit":{"primary_window":{"used_percent":9,"limit_window_seconds":604800,"reset_at":1777969707},"secondary_window":{"used_percent":25,"limit_window_seconds":18000,"reset_at":1777534802}},"rate_limit_reset_credits":{"available_count":2}}"#
    let parsed = try QuotaParser.parseAPIResponse(Data(bothWindows.utf8))
    check(parsed.fiveHour?.remainingPercent == 75, "5 小时窗口按时长识别")
    check(parsed.weekly?.remainingPercent == 91, "每周窗口按时长识别")
    check(parsed.resetCredits == 2, "解析剩余重置次数")

    let weeklyOnly = #"{"plan_type":"plus","rate_limit":{"primary_window":{"used_percent":3,"limit_window_seconds":604800,"reset_at":1784544496},"secondary_window":null},"rate_limit_reset_credits":{"available_count":0}}"#
    let weekly = try QuotaParser.parseAPIResponse(Data(weeklyOnly.utf8))
    check(weekly.fiveHour == nil, "保留缺失的 5 小时窗口")
    check(weekly.weekly?.remainingPercent == 97, "解析仅每周窗口")
    check(weekly.resetCredits == 0, "保留零次重置额度")

    let nullCredits = #"{"rate_limit":{"primary_window":null,"secondary_window":null},"rate_limit_reset_credits":null}"#
    let empty = try QuotaParser.parseAPIResponse(Data(nullCredits.utf8))
    check(empty.resetCredits == nil, "空重置额度保持未知")

    let sessionLine = #"{"timestamp":"2026-07-15T08:00:00Z","payload":{"rate_limits":{"plan_type":"pro","primary":{"used_percent":30,"window_minutes":300,"resets_at":1784106000},"secondary":{"used_percent":12,"window_minutes":10080,"resets_at":1784544496}}}}"#
    let fallback = QuotaParser.parseSessionLine(sessionLine)
    check(fallback?.fiveHour?.remainingPercent == 70, "解析本地 5 小时记录")
    check(fallback?.weekly?.remainingPercent == 88, "解析本地每周记录")
}

private func trendChecks() {
    let now = Date(timeIntervalSince1970: 1_789_000_000)
    let fiveHour = QuotaWindow(
        usedPercent: 70,
        windowSeconds: 18_000,
        resetAt: now.addingTimeInterval(7_200)
    )
    let usage = [
        QuotaUsageSample(timestamp: now.addingTimeInterval(-3_600), fiveHourUsedPercent: 50),
        QuotaUsageSample(timestamp: now, fiveHourUsedPercent: 70)
    ]
    let prediction = UsageAnalyticsService.calculateTrend(
        window: fiveHour,
        history: usage,
        useFiveHour: true,
        now: now
    )
    check(prediction.hasEnoughData, "趋势样本充足")
    check(abs(prediction.percentPerHour - 20) < 0.001, "计算每小时消耗速度")
    check(!prediction.expectedToLastUntilReset, "预测重置前耗尽")
    check(abs((prediction.estimatedExhaustAt?.timeIntervalSince(now) ?? 0) - 5_400) < 0.001, "计算预计耗尽时间")

    let weekly = QuotaWindow(
        usedPercent: 20,
        windowSeconds: 604_800,
        resetAt: now.addingTimeInterval(432_000)
    )
    let resetSamples = [
        QuotaUsageSample(timestamp: now.addingTimeInterval(-3_300), weeklyUsedPercent: 95),
        QuotaUsageSample(timestamp: now.addingTimeInterval(-1_800), weeklyUsedPercent: 10),
        QuotaUsageSample(timestamp: now, weeklyUsedPercent: 20)
    ]
    let afterReset = UsageAnalyticsService.calculateTrend(
        window: weekly,
        history: resetSamples,
        useFiveHour: false,
        now: now
    )
    check(abs(afterReset.percentPerHour - 20) < 0.001, "忽略窗口重置前样本")
}

do {
    try parserChecks()
    trendChecks()
} catch {
    failures += 1
    fputs("FAILED: \(error)\n", stderr)
}

if failures > 0 {
    fputs("FAILED: \(failures) assertion(s)\n", stderr)
    exit(1)
}
print("PASS: all self-tests")
