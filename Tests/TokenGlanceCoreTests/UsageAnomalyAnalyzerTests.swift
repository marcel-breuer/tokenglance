import Foundation
import Testing

@testable import TokenGlanceCore

@Suite("Usage anomaly detection")
struct UsageAnomalyAnalyzerTests {
  @Test("Detects a significant spike against recent hourly usage")
  func detectsSpike() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let start = DateCoding.parseISO8601("2026-06-29T08:00:00Z")!
    let events = [
      event(id: "one", timestamp: start, total: 1_000),
      event(id: "two", timestamp: start.addingTimeInterval(3_600), total: 1_200),
      event(id: "three", timestamp: start.addingTimeInterval(7_200), total: 900),
      event(id: "spike", timestamp: start.addingTimeInterval(10_800), total: 5_000),
    ]

    let anomalies = UsageAnomalyAnalyzer(calendar: calendar).analyze(
      events: events,
      period: .last24Hours,
      now: start.addingTimeInterval(14_400))

    #expect(anomalies.count == 1)
    #expect(anomalies[0].tokens == 5_000)
    #expect(anomalies[0].baselineTokens == 1_000)
    #expect(anomalies[0].multiplier == 5)
    #expect(anomalies[0].severity == .significant)
    #expect(anomalies[0].topTool == .codexCLI)
  }

  @Test("Ignores steady usage and small relative changes")
  func ignoresNormalUsage() {
    let start = DateCoding.parseISO8601("2026-06-29T08:00:00Z")!
    let events = [
      event(id: "one", timestamp: start, total: 1_000),
      event(id: "two", timestamp: start.addingTimeInterval(3_600), total: 1_100),
      event(id: "three", timestamp: start.addingTimeInterval(7_200), total: 900),
      event(id: "normal", timestamp: start.addingTimeInterval(10_800), total: 1_500),
    ]

    let anomalies = UsageAnomalyAnalyzer().analyze(
      events: events,
      period: .last24Hours,
      now: start.addingTimeInterval(14_400))

    #expect(anomalies.isEmpty)
  }
}

private func event(id: String, timestamp: Date, total: Int) -> UsageEvent {
  UsageEvent(
    id: id,
    collector: .codexCLI,
    tool: .codexCLI,
    provider: .openAI,
    model: "gpt-5",
    timestamp: timestamp,
    tokens: TokenBreakdown(inputTokens: total / 2, outputTokens: total / 2, totalTokens: total),
    sessionIdentifierHash: nil,
    projectIdentifierHash: nil,
    sourceKind: .localJSONL,
    sourceFingerprint: "fixture",
    accuracy: .exact,
    parserVersion: "test"
  )
}
