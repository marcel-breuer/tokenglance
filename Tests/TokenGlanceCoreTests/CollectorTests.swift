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
    let batch = try await collector.collect(since: nil)

    #expect(batch.events.count == 2)
    #expect(batch.events.compactMap(\.tokens.totalTokens).sorted() == [11, 17])
  }

  private func syntheticCodexJSONL(totalTokens: Int) -> String {
    """
    {"timestamp":"2026-06-28T10:00:00Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":\(totalTokens),"output_tokens":0,"total_tokens":\(totalTokens)}}}}

    """
  }
}
