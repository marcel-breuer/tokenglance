import Foundation

public struct ProjectUsageRow: Equatable, Identifiable, Sendable {
  public let projectIdentifierHash: String
  public let eventCount: Int
  public let tokens: TokenBreakdown
  public let lastUsed: Date
  public let estimatedCost: Double?

  public var id: String { projectIdentifierHash }
}

public struct ProjectUsageAnalyzer: Sendable {
  private let aggregator: UsageAggregator

  public init(aggregator: UsageAggregator = UsageAggregator()) {
    self.aggregator = aggregator
  }

  public func analyze(
    events: [UsageEvent],
    toolFilter: ToolIdentifier? = nil,
    modelFilter: String? = nil,
    costProfiles: [ModelCostProfile] = []
  ) -> [ProjectUsageRow] {
    let filtered = events.filter { event in
      event.projectIdentifierHash != nil
        && (toolFilter == nil || event.tool == toolFilter)
        && (modelFilter == nil || event.model == modelFilter)
    }
    let groups = Dictionary(grouping: filtered) { $0.projectIdentifierHash! }

    return groups.map { hash, projectEvents in
      let tokens = aggregator.combine(projectEvents.map(\.tokens))
      return ProjectUsageRow(
        projectIdentifierHash: hash,
        eventCount: projectEvents.count,
        tokens: tokens,
        lastUsed: projectEvents.map(\.timestamp).max() ?? .distantPast,
        estimatedCost: estimatedCost(for: projectEvents, costProfiles: costProfiles))
    }
    .sorted { first, second in
      if first.tokens.calculatedTotal == second.tokens.calculatedTotal {
        return first.projectIdentifierHash < second.projectIdentifierHash
      }
      return first.tokens.calculatedTotal > second.tokens.calculatedTotal
    }
  }

  private func estimatedCost(
    for events: [UsageEvent], costProfiles: [ModelCostProfile]
  ) -> Double? {
    let costs = events.compactMap { event -> Double? in
      guard let model = event.model,
        let profile = costProfiles.first(where: { $0.matches(model: model) })
      else { return nil }
      let tokens = event.tokens
      let inputCost = Double(tokens.inputTokens ?? 0) / 1_000_000 * profile.inputCostPerMillion
      let outputCost = Double(tokens.outputTokens ?? 0) / 1_000_000 * profile.outputCostPerMillion
      let cachedCost =
        Double(
          (tokens.cachedInputTokens ?? 0) + (tokens.cacheCreationTokens ?? 0)
        ) / 1_000_000 * profile.cachedInputCostPerMillion
      return inputCost + outputCost + cachedCost
    }
    return costs.isEmpty ? nil : costs.reduce(0, +)
  }
}
