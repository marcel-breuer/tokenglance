import Foundation
import Testing

@testable import TokenGlanceCore

@Suite("Local collectors")
struct CollectorTests {
  @Test("Codex collector reads session and archived session directories")
  func codexCollectorReadsMultipleSourceDirectories() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let sessions = root.appendingPathComponent("sessions", isDirectory: true)
    let archived = root.appendingPathComponent("archived_sessions", isDirectory: true)
    try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: archived, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    try syntheticCodexJSONL(totalTokens: 11).write(
      to: sessions.appendingPathComponent("session.jsonl"), atomically: true, encoding: .utf8)
    try syntheticCodexJSONL(totalTokens: 17).write(
      to: archived.appendingPathComponent("archived.jsonl"), atomically: true, encoding: .utf8)

    let collector = CodexCLICollector(sourceDirectories: [sessions, archived])
    let batch = try await collector.collect(since: [])

    #expect(batch.events.count == 2)
    #expect(batch.events.compactMap(\.tokens.totalTokens).sorted() == [11, 17])
  }

  @Test("Codex collector skips unchanged files using cursors")
  func codexCollectorSkipsUnchangedFilesUsingCursors() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let file = root.appendingPathComponent("session.jsonl")
    try syntheticCodexJSONL(totalTokens: 11).write(to: file, atomically: true, encoding: .utf8)

    let collector = CodexCLICollector(sourceDirectory: root)
    let firstBatch = try await collector.collect(since: [])
    let secondBatch = try await collector.collect(since: firstBatch.cursors)

    #expect(firstBatch.events.count == 1)
    #expect(firstBatch.cursors.count == 1)
    #expect(secondBatch.events.isEmpty)
    #expect(secondBatch.cursors == firstBatch.cursors)
  }

  @Test("Codex collector reparses changed files to preserve cumulative deltas")
  func codexCollectorReparsesChangedFiles() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let file = root.appendingPathComponent("session.jsonl")
    try syntheticCodexJSONL(totalTokens: 11).write(to: file, atomically: true, encoding: .utf8)

    let collector = CodexCLICollector(sourceDirectory: root)
    let firstBatch = try await collector.collect(since: [])
    let appended = syntheticCodexJSONL(totalTokens: 17)
    let handle = try FileHandle(forWritingTo: file)
    defer { try? handle.close() }
    try handle.seekToEnd()
    try handle.write(contentsOf: Data(appended.utf8))

    let changedBatch = try await collector.collect(since: firstBatch.cursors)

    #expect(changedBatch.events.count == 2)
    #expect(changedBatch.events.compactMap(\.tokens.totalTokens).sorted() == [6, 11])
    #expect(changedBatch.cursors.first?.offset ?? 0 > firstBatch.cursors.first?.offset ?? 0)
  }

  @Test("Claude Code collector reads OTLP telemetry files written by the local receiver")
  func claudeCodeCollectorReadsTelemetryDirectory() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let data = try fixture("ClaudeCode/telemetry.jsonl")
    try data.write(to: root.appendingPathComponent("claude-otel-2026-07-27.jsonl"))

    let collector = ClaudeCodeCollector(sourceDirectories: [root])
    let batch = try await collector.collect(since: [])

    #expect(batch.events.count == 4)
    #expect(batch.events.allSatisfy { $0.collector == .claudeCode })
  }

  @Test("Claude Code collector skips unchanged telemetry files using cursors")
  func claudeCodeCollectorSkipsUnchangedFilesUsingCursors() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let data = try fixture("ClaudeCode/telemetry.jsonl")
    try data.write(to: root.appendingPathComponent("claude-otel-2026-07-27.jsonl"))

    let collector = ClaudeCodeCollector(sourceDirectories: [root])
    let firstBatch = try await collector.collect(since: [])
    let secondBatch = try await collector.collect(since: firstBatch.cursors)

    #expect(firstBatch.events.count == 4)
    #expect(secondBatch.events.isEmpty)
    #expect(secondBatch.cursors == firstBatch.cursors)
  }

  @Test("Gemini CLI collector reads sanitized local token telemetry incrementally")
  func geminiCLICollectorReadsLocalTelemetry() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let raw = Data(#"{"resourceMetrics":[{"scopeMetrics":[{"metrics":[{"name":"gen_ai.client.token.usage","sum":{"dataPoints":[{"asInt":"40","timeUnixNano":"1782727200000000000","attributes":[{"key":"gen_ai.token.type","value":{"stringValue":"output"}},{"key":"gen_ai.request.model","value":{"stringValue":"gemini-3.8-flash"}}]}]}}]}]}]}"#.utf8)
    let sanitized = try #require(GeminiTelemetryParser.sanitizedMetricsJSONL(from: raw))
    try sanitized.write(to: root.appendingPathComponent("gemini-cli-otel-2026-10-24.jsonl"))

    let collector = GeminiCLICollector(sourceDirectories: [root])
    let firstBatch = try await collector.collect(since: [])
    let secondBatch = try await collector.collect(since: firstBatch.cursors)

    #expect(firstBatch.events.count == 1)
    #expect(firstBatch.events[0].collector == .geminiCLI)
    #expect(firstBatch.events[0].tokens.outputTokens == 40)
    #expect(secondBatch.events.isEmpty)
  }

  private func fixture(_ path: String) throws -> Data {
    let url = Bundle.module.resourceURL!.appendingPathComponent("Fixtures").appendingPathComponent(
      path)
    return try Data(contentsOf: url)
  }

  private func syntheticCodexJSONL(totalTokens: Int) -> String {
    """
    {"timestamp":"2026-06-28T10:00:00Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":\(totalTokens),"output_tokens":0,"total_tokens":\(totalTokens)}}}}

    """
  }
}
