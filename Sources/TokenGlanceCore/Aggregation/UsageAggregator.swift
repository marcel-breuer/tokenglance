import Foundation

public enum ReportingPeriod: String, CaseIterable, Codable, Sendable {
  case today
  case last24Hours
  case last7Days
  case last30Days

  public var displayName: String {
    switch self {
    case .today: "Today"
    case .last24Hours: "Last 24 Hours"
    case .last7Days: "Last 7 Days"
    case .last30Days: "Last 30 Days"
    }
  }
}

public enum BucketGranularity: String, Codable, Sendable {
  case hour
  case day
}

public struct UsageBucket: Identifiable, Equatable, Sendable {
  public let id: Date
  public let start: Date
  public let tokens: TokenBreakdown
}

public struct UsageSummary: Equatable, Sendable {
  public let period: ReportingPeriod
  public let granularity: BucketGranularity
  public let totals: TokenBreakdown
  public let buckets: [UsageBucket]
  public let byTool: [ToolIdentifier: TokenBreakdown]
  public let byModel: [String: TokenBreakdown]
  public let accuracy: UsageAccuracy
}

public struct UsageAggregator: Sendable {
  private let calendar: Calendar

  public init(calendar: Calendar = .current) {
    self.calendar = calendar
  }

  public func interval(for period: ReportingPeriod, now: Date = Date()) -> DateInterval {
    switch period {
    case .today:
      let start = calendar.startOfDay(for: now)
      return DateInterval(start: start, end: now)
    case .last24Hours:
      return DateInterval(start: now.addingTimeInterval(-24 * 60 * 60), end: now)
    case .last7Days:
      return DateInterval(start: calendar.date(byAdding: .day, value: -7, to: now) ?? now, end: now)
    case .last30Days:
      return DateInterval(
        start: calendar.date(byAdding: .day, value: -30, to: now) ?? now, end: now)
    }
  }

  public func summarize(
    events: [UsageEvent],
    period: ReportingPeriod,
    toolFilter: ToolIdentifier? = nil,
    modelFilter: String? = nil,
    now: Date = Date()
  ) -> UsageSummary {
    let interval = interval(for: period, now: now)
    let granularity: BucketGranularity = (period == .today || period == .last24Hours) ? .hour : .day
    let filtered = events.filter { event in
      interval.contains(event.timestamp)
        && (toolFilter == nil || event.tool == toolFilter)
        && (modelFilter == nil || event.model == modelFilter)
    }

    let bucketGroups = Dictionary(grouping: filtered) { event in
      bucketStart(for: event.timestamp, granularity: granularity)
    }
    let buckets =
      bucketGroups
      .map { UsageBucket(id: $0.key, start: $0.key, tokens: combine($0.value.map(\.tokens))) }
      .sorted { $0.start < $1.start }

    let toolGroups = Dictionary(grouping: filtered, by: \.tool)
    let modelGroups = Dictionary(grouping: filtered) { $0.model ?? "Unknown model" }
    let accuracy: UsageAccuracy = filtered.contains { $0.accuracy != .exact } ? .partial : .exact

    return UsageSummary(
      period: period,
      granularity: granularity,
      totals: combine(filtered.map(\.tokens)),
      buckets: buckets,
      byTool: toolGroups.mapValues { combine($0.map(\.tokens)) },
      byModel: modelGroups.mapValues { combine($0.map(\.tokens)) },
      accuracy: filtered.isEmpty ? .unavailable : accuracy
    )
  }

  private func bucketStart(for date: Date, granularity: BucketGranularity) -> Date {
    switch granularity {
    case .hour:
      return calendar.dateInterval(of: .hour, for: date)?.start ?? date
    case .day:
      return calendar.startOfDay(for: date)
    }
  }

  public func combine(_ values: [TokenBreakdown]) -> TokenBreakdown {
    func sum(_ keyPath: KeyPath<TokenBreakdown, Int?>) -> Int? {
      let numbers = values.compactMap { $0[keyPath: keyPath] }
      return numbers.isEmpty ? nil : numbers.reduce(0, +)
    }

    return TokenBreakdown(
      inputTokens: sum(\.inputTokens),
      outputTokens: sum(\.outputTokens),
      cachedInputTokens: sum(\.cachedInputTokens),
      cacheCreationTokens: sum(\.cacheCreationTokens),
      reasoningTokens: sum(\.reasoningTokens),
      otherTokens: sum(\.otherTokens),
      totalTokens: sum(\.totalTokens)
    )
  }
}
