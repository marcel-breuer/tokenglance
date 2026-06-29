import Foundation
import Testing

@testable import TokenGlanceCore

@Suite("Weekly usage report")
struct WeeklyUsageReportTests {
  @Test("Markdown report includes trends, peaks, models, and cache share")
  func markdownReportIncludesWeeklySignals() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = DateCoding.parseISO8601("2026-06-29T12:00:00Z")!
    let events = [
      event(
        id: "current-1", timestamp: "2026-06-24T10:15:00Z", model: "gpt-5",
        tokens: TokenBreakdown(
          inputTokens: 100, outputTokens: 100, cachedInputTokens: 50, totalTokens: 250)),
      event(
        id: "current-2", timestamp: "2026-06-27T14:10:00Z", model: "claude",
        tokens: TokenBreakdown(inputTokens: 200, outputTokens: 100, totalTokens: 300)),
      event(
        id: "current-3", timestamp: "2026-06-27T14:40:00Z", model: "gpt-5",
        tokens: TokenBreakdown(inputTokens: 150, outputTokens: 150, totalTokens: 300)),
      event(
        id: "previous-1", timestamp: "2026-06-20T09:00:00Z", model: "gpt-5",
        tokens: TokenBreakdown(inputTokens: 100, outputTokens: 100, totalTokens: 200)),
    ]

    let markdown = WeeklyUsageReportBuilder(calendar: calendar).markdown(events: events, now: now)

    #expect(markdown.contains("Period: 2026-06-23 to 2026-06-29"))
    #expect(markdown.contains("- Total tokens: 850"))
    #expect(markdown.contains("- Previous week: 200"))
    #expect(markdown.contains("- Change: +650 tokens (+325%)"))
    #expect(markdown.contains("- Cache share: 5.9%"))
    #expect(markdown.contains("- Busiest day: 2026-06-27 with 600 tokens"))
    #expect(markdown.contains("- Busiest hour: 2026-06-27 14:00 with 600 tokens"))
    #expect(markdown.contains("| gpt-5 | 550 | 64.7% |"))
    #expect(markdown.contains("| claude | 300 | 35.3% |"))
    #expect(markdown.contains("| Cached input | 50 | 5.9% |"))
  }
}

private func event(id: String, timestamp: String, model: String?, tokens: TokenBreakdown)
  -> UsageEvent
{
  UsageEvent(
    id: id,
    collector: .codexCLI,
    tool: .codexCLI,
    provider: .openAI,
    model: model,
    timestamp: DateCoding.parseISO8601(timestamp)!,
    tokens: tokens,
    sessionIdentifierHash: nil,
    projectIdentifierHash: nil,
    sourceKind: .localJSONL,
    sourceFingerprint: "fixture",
    accuracy: .exact,
    parserVersion: "test"
  )
}
