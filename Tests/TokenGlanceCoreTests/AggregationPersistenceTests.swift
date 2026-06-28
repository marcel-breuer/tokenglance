import Foundation
import Testing

@testable import TokenGlanceCore

@Suite("Aggregation and persistence")
struct AggregationPersistenceTests {
  @Test("Aggregator groups hourly buckets and totals")
  func hourlyAggregation() {
    let start = DateCoding.parseISO8601("2026-06-28T10:00:00Z")!
    let events = [
      event(id: "1", timestamp: start, tool: .codexCLI, model: "gpt-5", total: 10),
      event(
        id: "2", timestamp: start.addingTimeInterval(1800), tool: .codexCLI, model: "gpt-5",
        total: 20),
      event(
        id: "3", timestamp: start.addingTimeInterval(3700), tool: .claudeCode, model: "claude",
        total: 30),
    ]
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let summary = UsageAggregator(calendar: calendar).summarize(
      events: events, period: .last24Hours, now: start.addingTimeInterval(7200))
    #expect(summary.totals.calculatedTotal == 60)
    #expect(summary.buckets.count == 2)
    #expect(summary.byTool[.codexCLI]?.calculatedTotal == 30)
  }

  @Test("SQLite persistence deduplicates event IDs")
  func persistenceDeduplicates() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      .appendingPathComponent("db.sqlite")
    let database = UsageDatabase(url: url)
    try await database.open()
    let usage = event(id: "same", timestamp: Date(), tool: .codexCLI, model: "gpt-5", total: 10)
    let inserted = try await database.importBatch(CollectionBatch(events: [usage, usage]))
    #expect(inserted == 1)
    let events = try await database.fetchEvents(
      from: Date(timeIntervalSince1970: 0), to: Date().addingTimeInterval(10))
    #expect(events.count == 1)
  }
}

private func event(id: String, timestamp: Date, tool: ToolIdentifier, model: String, total: Int)
  -> UsageEvent
{
  UsageEvent(
    id: id,
    collector: tool == .codexCLI ? .codexCLI : .claudeCode,
    tool: tool,
    provider: tool == .geminiCLI ? .google : (tool == .claudeCode ? .anthropic : .openAI),
    model: model,
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
