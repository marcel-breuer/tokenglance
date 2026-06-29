import Foundation
import Testing

@testable import TokenGlanceCore

@Suite("Model efficiency")
struct ModelEfficiencyTests {
  @Test("Analyzer ranks models and estimates local cost profiles")
  func ranksModelsAndEstimatesCost() {
    let events = [
      event(id: "1", model: "gpt-5", input: 1_000, output: 2_000, cached: 500, reasoning: 500),
      event(id: "2", model: "gpt-5", input: 1_000, output: 1_000, cached: 0, reasoning: 0),
      event(id: "3", model: "claude", input: 300, output: 300, cached: 0, reasoning: 0),
    ]
    let profiles = [
      ModelCostProfile(
        modelPattern: "gpt",
        inputCostPerMillion: 2,
        outputCostPerMillion: 10,
        cachedInputCostPerMillion: 0.5)
    ]

    let rows = ModelEfficiencyAnalyzer().analyze(events: events, costProfiles: profiles)

    #expect(rows.map(\.model) == ["gpt-5", "claude"])
    #expect(rows[0].tokens.calculatedTotal == 6_000)
    #expect(rows[0].averageTokensPerEvent == 3_000)
    #expect(rows[0].cacheShare == 500.0 / 6_000.0)
    #expect(rows[0].reasoningShare == 500.0 / 6_000.0)
    #expect(rows[0].estimatedCost == 0.03425)
    #expect(rows[1].estimatedCost == nil)
  }
}

private func event(
  id: String,
  model: String,
  input: Int,
  output: Int,
  cached: Int,
  reasoning: Int
) -> UsageEvent {
  UsageEvent(
    id: id,
    collector: .codexCLI,
    tool: .codexCLI,
    provider: .openAI,
    model: model,
    timestamp: Date(),
    tokens: TokenBreakdown(
      inputTokens: input,
      outputTokens: output,
      cachedInputTokens: cached,
      reasoningTokens: reasoning),
    sessionIdentifierHash: nil,
    projectIdentifierHash: nil,
    sourceKind: .localJSONL,
    sourceFingerprint: "fixture",
    accuracy: .exact,
    parserVersion: "test"
  )
}
