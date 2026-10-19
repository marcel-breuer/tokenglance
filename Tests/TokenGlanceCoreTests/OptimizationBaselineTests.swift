import Foundation
import Testing

@testable import TokenGlanceCore

@Suite("Optimization baselines")
struct OptimizationBaselineTests {
  @Test("Synthetic large history records parser, report, and storage baseline")
  func syntheticHistoryBaseline() async throws {
    let recordCount = 10_000
    let now = DateCoding.parseISO8601("2026-10-19T10:00:00Z")!
    let line = #"{"type":"token_count","timestamp":"2026-10-19T10:00:00Z","session_id":"synthetic-session","cwd":"/synthetic/workspace","last_token_usage":{"input_tokens":100,"output_tokens":50,"total_tokens":150}}"#
    var fixture = String()
    fixture.reserveCapacity(recordCount * (line.utf8.count + 1))
    for _ in 0..<recordCount {
      fixture.append(line)
      fixture.append("\n")
    }
    let fixtureData = Data(fixture.utf8)

    let parserStart = DispatchTime.now().uptimeNanoseconds
    let batch = CodexUsageParser().parseJSONLines(
      fixtureData, sourceFingerprint: "synthetic-large-history", importedAt: now)
    let parserEnd = DispatchTime.now().uptimeNanoseconds
    #expect(batch.events.count == recordCount)

    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let databaseURL = directory.appendingPathComponent("usage.sqlite")
    let database = UsageDatabase(url: databaseURL)
    try await database.open()

    var importMilliseconds = 0.0
    var storageMeasurements: [String] = []
    var previousCheckpoint = 0
    for checkpoint in [1_000, 5_000, recordCount] {
      let importStart = DispatchTime.now().uptimeNanoseconds
      let inserted = try await database.importBatch(
        CollectionBatch(events: Array(batch.events[previousCheckpoint..<checkpoint])))
      let importEnd = DispatchTime.now().uptimeNanoseconds
      #expect(inserted == checkpoint - previousCheckpoint)
      importMilliseconds += Double(importEnd - importStart) / 1_000_000

      await database.close()
      let bytes = try #require(
        FileManager.default.attributesOfItem(atPath: databaseURL.path)[.size] as? Int)
      storageMeasurements.append("\(checkpoint):\(bytes)")
      previousCheckpoint = checkpoint
      if checkpoint < recordCount {
        try await database.open()
      }
    }
    try await database.open()

    let fetchStart = DispatchTime.now().uptimeNanoseconds
    let storedEvents = try await database.fetchEvents(
      from: now.addingTimeInterval(-60), to: now.addingTimeInterval(60))
    let fetchEnd = DispatchTime.now().uptimeNanoseconds
    #expect(storedEvents.count == recordCount)

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let aggregationStart = DispatchTime.now().uptimeNanoseconds
    let summary = UsageAggregator(calendar: calendar).summarize(
      events: storedEvents, period: .last30Days, now: now.addingTimeInterval(60))
    let aggregationEnd = DispatchTime.now().uptimeNanoseconds
    #expect(summary.totals.calculatedTotal == recordCount * 150)

    let reportStart = DispatchTime.now().uptimeNanoseconds
    let report = WeeklyUsageReportBuilder(calendar: calendar).markdown(
      events: storedEvents, now: now.addingTimeInterval(60))
    let reportEnd = DispatchTime.now().uptimeNanoseconds
    #expect(report.contains("Total tokens: 1500000"))

    await database.close()
    let databaseBytes = try #require(
      FileManager.default.attributesOfItem(atPath: databaseURL.path)[.size] as? Int)
    #expect(databaseBytes > 0)

    func milliseconds(_ start: UInt64, _ end: UInt64) -> Double {
      Double(end - start) / 1_000_000
    }
    let measurements = [
      "records=\(recordCount)",
      "fixture_bytes=\(fixtureData.count)",
      "parser_ms=\(milliseconds(parserStart, parserEnd))",
      "import_ms=\(importMilliseconds)",
      "fetch_ms=\(milliseconds(fetchStart, fetchEnd))",
      "aggregation_ms=\(milliseconds(aggregationStart, aggregationEnd))",
      "weekly_report_ms=\(milliseconds(reportStart, reportEnd))",
      "storage_bytes_at_records=\(storageMeasurements.joined(separator: ","))",
      "bytes_per_event_at_10000=\(Double(databaseBytes) / Double(recordCount))",
    ]
    print("Optimization baseline: \(measurements.joined(separator: ", "))")
  }
}
