import Foundation
import Testing

@testable import TokenGlanceCore

@Suite("Usage pulse")
struct UsagePulseTests {
  @Test("Empty usage stays calm")
  func emptyUsageStaysCalm() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = DateCoding.parseISO8601("2026-06-29T12:00:00Z")!

    let pulse = UsagePulseAnalyzer(calendar: calendar).analyze(events: [], now: now)

    #expect(pulse.tokensLastHour == 0)
    #expect(pulse.burnRatePerHour == 0)
    #expect(pulse.projectedTokensToday == 0)
    #expect(pulse.weather == .calm)
  }

  @Test("Recent usage reports active burn rate and projection")
  func recentUsageReportsActiveBurnRateAndProjection() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = DateCoding.parseISO8601("2026-06-29T12:00:00Z")!
    let events = [
      event(id: "morning", timestamp: "2026-06-29T08:00:00Z", total: 2_000),
      event(id: "recent", timestamp: "2026-06-29T11:30:00Z", total: 2_000),
    ]

    let pulse = UsagePulseAnalyzer(calendar: calendar).analyze(events: events, now: now)

    #expect(pulse.tokensLastHour == 2_000)
    #expect(pulse.burnRatePerHour == 2_000)
    #expect(pulse.dayAveragePerHour == 333)
    #expect(pulse.projectedTokensToday == 8_000)
    #expect(pulse.weather == .active)
  }

  @Test("Large recent spike reports stormy weather")
  func largeRecentSpikeReportsStormyWeather() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = DateCoding.parseISO8601("2026-06-29T12:00:00Z")!
    let events = [
      event(id: "baseline", timestamp: "2026-06-29T08:00:00Z", total: 2_000),
      event(id: "spike", timestamp: "2026-06-29T11:30:00Z", total: 25_000),
    ]

    let pulse = UsagePulseAnalyzer(calendar: calendar).analyze(events: events, now: now)

    #expect(pulse.burnRatePerHour == 25_000)
    #expect(pulse.projectedTokensToday == 54_000)
    #expect(pulse.weather == .stormy)
  }
}

private func event(id: String, timestamp: String, total: Int) -> UsageEvent {
  UsageEvent(
    id: id,
    collector: .codexCLI,
    tool: .codexCLI,
    provider: .openAI,
    model: "gpt-5",
    timestamp: DateCoding.parseISO8601(timestamp)!,
    tokens: TokenBreakdown(inputTokens: total / 2, outputTokens: total / 2, totalTokens: total),
    sessionIdentifierHash: nil,
    projectIdentifierHash: nil,
    sourceKind: .localJSONL,
    sourceFingerprint: "fixture",
    accuracy: .exact,
    parserVersion: "test"
  )
}
