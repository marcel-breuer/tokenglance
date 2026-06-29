import Foundation

public struct ModelEfficiencyRow: Equatable, Identifiable, Sendable {
  public var id: String { model }
  public let model: String
  public let eventCount: Int
  public let tokens: TokenBreakdown
  public let averageTokensPerEvent: Int
  public let inputOutputRatio: Double?
  public let cacheShare: Double
  public let reasoningShare: Double
  public let estimatedCost: Double?
}

public struct ModelEfficiencyAnalyzer: Sendable {
  private let aggregator: UsageAggregator

  public init(aggregator: UsageAggregator = UsageAggregator()) {
    self.aggregator = aggregator
  }

  public func analyze(events: [UsageEvent], costProfiles: [ModelCostProfile])
    -> [ModelEfficiencyRow]
  {
    Dictionary(grouping: events) { $0.model ?? "Unknown model" }
      .map { model, events in
        let tokens = aggregator.combine(events.map(\.tokens))
        let total = max(tokens.calculatedTotal, 0)
        let output = tokens.outputTokens ?? 0
        let inputOutputRatio = output > 0 ? Double(tokens.inputTokens ?? 0) / Double(output) : nil
        let cacheTokens = (tokens.cachedInputTokens ?? 0) + (tokens.cacheCreationTokens ?? 0)
        return ModelEfficiencyRow(
          model: model,
          eventCount: events.count,
          tokens: tokens,
          averageTokensPerEvent: events.isEmpty
            ? 0 : Int((Double(total) / Double(events.count)).rounded()),
          inputOutputRatio: inputOutputRatio,
          cacheShare: total > 0 ? Double(cacheTokens) / Double(total) : 0,
          reasoningShare: total > 0 ? Double(tokens.reasoningTokens ?? 0) / Double(total) : 0,
          estimatedCost: estimatedCost(for: model, tokens: tokens, profiles: costProfiles))
      }
      .sorted { first, second in
        if first.tokens.calculatedTotal == second.tokens.calculatedTotal {
          return first.model < second.model
        }
        return first.tokens.calculatedTotal > second.tokens.calculatedTotal
      }
  }

  private func estimatedCost(
    for model: String,
    tokens: TokenBreakdown,
    profiles: [ModelCostProfile]
  ) -> Double? {
    guard let profile = profiles.first(where: { $0.matches(model: model) }) else { return nil }
    let inputCost = Double(tokens.inputTokens ?? 0) / 1_000_000 * profile.inputCostPerMillion
    let outputCost = Double(tokens.outputTokens ?? 0) / 1_000_000 * profile.outputCostPerMillion
    let cachedCost =
      Double((tokens.cachedInputTokens ?? 0) + (tokens.cacheCreationTokens ?? 0)) / 1_000_000
      * profile.cachedInputCostPerMillion
    return inputCost + outputCost + cachedCost
  }
}
