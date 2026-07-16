import Foundation

public enum UsageAnomalySeverity: String, Codable, Equatable, Sendable {
  case notable
  case significant
}

public struct UsageAnomaly: Codable, Equatable, Identifiable, Sendable {
  public let start: Date
  public let tokens: Int
  public let baselineTokens: Int
  public let multiplier: Double
  public let severity: UsageAnomalySeverity
  public let topTool: ToolIdentifier?
  public let topModel: String?

  public var id: Date { start }
}

public struct UsageAnomalyAnalyzer: Sendable {
  private let calendar: Calendar
  private let aggregator: UsageAggregator

  public init(calendar: Calendar = .current) {
    self.calendar = calendar
    self.aggregator = UsageAggregator(calendar: calendar)
  }

  public func analyze(
    events: [UsageEvent],
    period: ReportingPeriod,
    toolFilter: ToolIdentifier? = nil,
    modelFilter: String? = nil,
    now: Date = Date()
  ) -> [UsageAnomaly] {
    let interval = aggregator.interval(for: period, now: now)
    let filtered = events.filter { event in
      interval.contains(event.timestamp)
        && (toolFilter == nil || event.tool == toolFilter)
        && (modelFilter == nil || event.model == modelFilter)
    }
    let granularity: BucketGranularity =
      (period == .today || period == .last24Hours) ? .hour : .day
    let bucketGroups = Dictionary(grouping: filtered) {
      bucketStart(for: $0.timestamp, granularity: granularity)
    }
    let buckets = bucketGroups.map { start, events in
      AnomalyBucket(start: start, events: events, tokens: aggregator.combine(events.map(\.tokens)))
    }
    .sorted { $0.start < $1.start }

    guard buckets.count >= 4 else { return [] }

    var anomalies: [UsageAnomaly] = []
    for index in 3..<buckets.count {
      let baselineBuckets = buckets[max(0, index - 6)..<index].filter {
        $0.tokens.calculatedTotal > 0
      }
      guard baselineBuckets.count >= 3 else { continue }

      let baseline = median(baselineBuckets.map { $0.tokens.calculatedTotal })
      let total = buckets[index].tokens.calculatedTotal
      guard baseline > 0 else { continue }
      let multiplier = Double(total) / Double(baseline)
      let delta = total - baseline
      guard multiplier >= 2, delta >= 1_000 else { continue }

      anomalies.append(
        UsageAnomaly(
          start: buckets[index].start,
          tokens: total,
          baselineTokens: baseline,
          multiplier: multiplier,
          severity: multiplier >= 3 || delta >= 25_000 ? .significant : .notable,
          topTool: topTool(in: buckets[index].events),
          topModel: topModel(in: buckets[index].events)))
    }

    return anomalies.sorted { first, second in
      if first.tokens == second.tokens {
        return first.start > second.start
      }
      return first.tokens > second.tokens
    }
  }

  private func bucketStart(for date: Date, granularity: BucketGranularity) -> Date {
    switch granularity {
    case .hour:
      return calendar.dateInterval(of: .hour, for: date)?.start ?? date
    case .day:
      return calendar.startOfDay(for: date)
    }
  }

  private func median(_ values: [Int]) -> Int {
    let sorted = values.sorted()
    let middle = sorted.count / 2
    if sorted.count.isMultiple(of: 2) {
      return Int(
        ((Double(sorted[middle - 1]) + Double(sorted[middle])) / 2.0).rounded())
    }
    return sorted[middle]
  }

  private func topTool(in events: [UsageEvent]) -> ToolIdentifier? {
    Dictionary(grouping: events, by: \.tool)
      .max { first, second in
        aggregator.combine(first.value.map(\.tokens)).calculatedTotal
          < aggregator.combine(second.value.map(\.tokens)).calculatedTotal
      }?
      .key
  }

  private func topModel(in events: [UsageEvent]) -> String? {
    let models = events.compactMap(\.model)
    guard !models.isEmpty else { return nil }
    return Dictionary(grouping: models, by: { $0 })
      .max { $0.value.count < $1.value.count }?
      .key
  }
}

private struct AnomalyBucket {
  let start: Date
  let events: [UsageEvent]
  let tokens: TokenBreakdown
}
