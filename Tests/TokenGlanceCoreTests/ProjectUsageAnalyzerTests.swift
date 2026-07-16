import Foundation
import Testing

@testable import TokenGlanceCore

@Suite("Project usage aggregation")
struct ProjectUsageAnalyzerTests {
  @Test("Groups only known projects and sorts by token total")
  func groupsProjects() {
    let now = DateCoding.parseISO8601("2026-06-29T12:00:00Z")!
    let alpha = Hashing.privacyHash("/workspace/alpha", salt: "tokenglance-local")
    let beta = Hashing.privacyHash("/workspace/beta", salt: "tokenglance-local")
    let events = [
      event(id: "alpha-1", project: alpha, total: 10, timestamp: now),
      event(id: "alpha-2", project: alpha, total: 30, timestamp: now.addingTimeInterval(60)),
      event(id: "beta-1", project: beta, total: 20, timestamp: now.addingTimeInterval(120)),
      event(id: "unknown", project: nil, total: 100, timestamp: now.addingTimeInterval(180)),
    ]

    let rows = ProjectUsageAnalyzer().analyze(events: events)

    #expect(rows.map(\.projectIdentifierHash) == [alpha, beta])
    #expect(rows.map(\.tokens.calculatedTotal) == [40, 20])
    #expect(rows[0].eventCount == 2)
    #expect(rows[0].lastUsed == now.addingTimeInterval(60))
  }

  @Test("Applies tool and model filters")
  func filtersProjects() {
    let alpha = Hashing.privacyHash("/workspace/alpha", salt: "tokenglance-local")
    let events = [
      event(id: "codex", project: alpha, total: 10, tool: .codexCLI, model: "gpt-5"),
      event(
        id: "claude", project: alpha, total: 25, tool: .claudeCode, model: "claude-sonnet"),
    ]

    let rows = ProjectUsageAnalyzer().analyze(
      events: events, toolFilter: .codexCLI, modelFilter: "gpt-5")

    #expect(rows.count == 1)
    #expect(rows[0].tokens.calculatedTotal == 10)
  }
}

private func event(
  id: String,
  project: String?,
  total: Int,
  tool: ToolIdentifier = .codexCLI,
  model: String = "gpt-5",
  timestamp: Date = Date()
) -> UsageEvent {
  UsageEvent(
    id: id,
    collector: tool == .codexCLI ? .codexCLI : .claudeCode,
    tool: tool,
    provider: tool == .claudeCode ? .anthropic : .openAI,
    model: model,
    timestamp: timestamp,
    tokens: TokenBreakdown(inputTokens: total / 2, outputTokens: total / 2, totalTokens: total),
    sessionIdentifierHash: nil,
    projectIdentifierHash: project,
    sourceKind: .localJSONL,
    sourceFingerprint: "fixture",
    accuracy: .exact,
    parserVersion: "test"
  )
}
