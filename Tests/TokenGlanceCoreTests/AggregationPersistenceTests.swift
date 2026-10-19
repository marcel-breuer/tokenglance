import Foundation
import SQLite3
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

  @Test("Sparkline series uses recent bucket totals and normalizes to peak")
  func sparklineSeriesNormalizesBucketTotals() {
    let start = DateCoding.parseISO8601("2026-06-28T10:00:00Z")!
    let events = [
      event(id: "1", timestamp: start, tool: .codexCLI, model: "gpt-5", total: 10),
      event(
        id: "2", timestamp: start.addingTimeInterval(3600), tool: .codexCLI, model: "gpt-5",
        total: 20),
      event(
        id: "3", timestamp: start.addingTimeInterval(7200), tool: .codexCLI, model: "gpt-5",
        total: 40),
    ]
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let summary = UsageAggregator(calendar: calendar).summarize(
      events: events, period: .last24Hours, now: start.addingTimeInterval(10_800))
    let series = UsageSparklineSeries(summary: summary, maxPoints: 2)

    #expect(series.values == [20, 40])
    #expect(series.normalizedValues == [0.5, 1.0])
    #expect(series.isRenderable)
  }

  @Test("SQLite persistence deduplicates event IDs")
  func persistenceDeduplicates() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      .appendingPathComponent("db.sqlite")
    let database = UsageDatabase(url: url)
    try await database.open()
    let schemaVersion = try await database.schemaVersion()
    #expect(schemaVersion == 1)
    let usage = event(id: "same", timestamp: Date(), tool: .codexCLI, model: "gpt-5", total: 10)
    let inserted = try await database.importBatch(CollectionBatch(events: [usage, usage]))
    #expect(inserted == 1)
    let events = try await database.fetchEvents(
      from: Date(timeIntervalSince1970: 0), to: Date().addingTimeInterval(10))
    #expect(events.count == 1)
  }

  @Test("SQLite migration preserves databases with a newer schema version")
  func migrationRejectsNewerSchemaWithoutChangingVersion() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("db.sqlite")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    var connection: OpaquePointer?
    let openResult = sqlite3_open(url.path, &connection)
    #expect(openResult == SQLITE_OK)
    let versionResult = sqlite3_exec(connection, "PRAGMA user_version = 99", nil, nil, nil)
    #expect(versionResult == SQLITE_OK)
    let closeResult = sqlite3_close(connection)
    #expect(closeResult == SQLITE_OK)

    let database = UsageDatabase(url: url)
    do {
      try await database.open()
      #expect(Bool(false), "A newer database schema should be rejected")
    } catch DatabaseError.unsupportedSchema(let found, let supported) {
      #expect(found == 99)
      #expect(supported == 1)
    }

    var verificationConnection: OpaquePointer?
    let verificationOpenResult = sqlite3_open(url.path, &verificationConnection)
    #expect(verificationOpenResult == SQLITE_OK)
    var statement: OpaquePointer?
    let prepareResult = sqlite3_prepare_v2(
      verificationConnection, "PRAGMA user_version", -1, &statement, nil)
    #expect(prepareResult == SQLITE_OK)
    let stepResult = sqlite3_step(statement)
    #expect(stepResult == SQLITE_ROW)
    #expect(sqlite3_column_int(statement, 0) == 99)
    let finalizeResult = sqlite3_finalize(statement)
    #expect(finalizeResult == SQLITE_OK)
    let verificationCloseResult = sqlite3_close(verificationConnection)
    #expect(verificationCloseResult == SQLITE_OK)
  }

  @Test("SQLite persistence backfills missing model without duplicating events")
  func persistenceBackfillsModel() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      .appendingPathComponent("db.sqlite")
    let database = UsageDatabase(url: url)
    try await database.open()

    let timestamp = Date()
    let first = event(id: "same", timestamp: timestamp, tool: .codexCLI, model: nil, total: 10)
    let second = event(
      id: "same", timestamp: timestamp, tool: .codexCLI, model: "gpt-5.4", total: 10)
    let inserted = try await database.importBatch(CollectionBatch(events: [first, second]))

    #expect(inserted == 1)
    let events = try await database.fetchEvents(
      from: Date(timeIntervalSince1970: 0), to: Date().addingTimeInterval(10))
    #expect(events.count == 1)
    #expect(events[0].model == "gpt-5.4")
  }

  @Test("SQLite persistence returns stored collection cursors")
  func persistenceReturnsCollectionCursors() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      .appendingPathComponent("db.sqlite")
    let database = UsageDatabase(url: url)
    try await database.open()

    let cursor = CollectionCursor(
      sourceFingerprint: "source-a",
      offset: 42,
      updatedAt: Date(timeIntervalSince1970: 1_803_000_000))
    _ = try await database.importBatch(CollectionBatch(events: [], cursors: [cursor]))

    let cursors = try await database.collectionCursors()
    #expect(cursors == [cursor])
  }
}

private func event(id: String, timestamp: Date, tool: ToolIdentifier, model: String?, total: Int)
  -> UsageEvent
{
  UsageEvent(
    id: id,
    collector: tool == .codexCLI ? .codexCLI : .claudeCode,
    tool: tool,
    provider: tool == .antigravity ? .google : (tool == .claudeCode ? .anthropic : .openAI),
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
