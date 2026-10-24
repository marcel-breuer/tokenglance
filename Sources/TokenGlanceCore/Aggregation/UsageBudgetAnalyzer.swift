import Foundation

public enum UsageBudgetPeriod: String, Codable, CaseIterable, Sendable {
  case day
  case week
  case month
}

public enum UsageBudgetMetric: String, Codable, CaseIterable, Sendable {
  case tokens
  case estimatedCost
}

public enum UsageBudgetAlertMode: String, Codable, CaseIterable, Sendable {
  case actual
  case forecast
  case either
}

public struct UsageBudget: Codable, Equatable, Identifiable, Sendable {
  public var id: String
  public var name: String
  public var period: UsageBudgetPeriod
  public var metric: UsageBudgetMetric
  public var limit: Double
  public var alertThresholds: [Int]
  public var alertMode: UsageBudgetAlertMode
  public var isEnabled: Bool

  public init(
    id: String = UUID().uuidString,
    name: String = "Monthly token budget",
    period: UsageBudgetPeriod = .month,
    metric: UsageBudgetMetric = .tokens,
    limit: Double = 1_000_000,
    alertThresholds: [Int] = [50, 80, 100],
    alertMode: UsageBudgetAlertMode = .either,
    isEnabled: Bool = true
  ) {
    self.id = id
    self.name = name
    self.period = period
    self.metric = metric
    self.limit = limit.isFinite ? max(0, limit) : 0
    self.alertThresholds = Array(Set(alertThresholds.filter { (1...100).contains($0) })).sorted()
    self.alertMode = alertMode
    self.isEnabled = isEnabled
  }
}

public struct UsageBudgetAlert: Equatable, Identifiable, Sendable {
  public let id: String
  public let budgetName: String
  public let threshold: Int
  public let currentAmount: Double
  public let projectedAmount: Double
  public let metric: UsageBudgetMetric
  public let isForecast: Bool
}

public struct UsageBudgetAnalyzer: Sendable {
  private let calendar: Calendar

  public init(calendar: Calendar = .current) {
    self.calendar = calendar
  }

  public func periodStart(for period: UsageBudgetPeriod, at date: Date) -> Date {
    let component: Calendar.Component = switch period {
    case .day: .day
    case .week: .weekOfYear
    case .month: .month
    }
    return calendar.dateInterval(of: component, for: date)?.start ?? calendar.startOfDay(for: date)
  }

  public func analyze(
    budget: UsageBudget,
    events: [UsageEvent],
    costProfiles: [ModelCostProfile],
    now: Date = Date()
  ) -> [UsageBudgetAlert] {
    guard budget.isEnabled, budget.limit > 0 else { return [] }
    let start = periodStart(for: budget.period, at: now)
    let end = calendar.dateInterval(of: budget.period.calendarComponent, for: now)?.end ?? now
    let currentEvents = events.filter { $0.timestamp >= start && $0.timestamp <= now }
    let amount: Double
    switch budget.metric {
    case .tokens:
      amount = Double(currentEvents.reduce(0) { $0 + max(0, $1.tokens.calculatedTotal) })
    case .estimatedCost:
      guard let estimate = estimatedCost(for: currentEvents, profiles: costProfiles) else { return [] }
      amount = estimate
    }
    let elapsed = max(0, min(1, now.timeIntervalSince(start) / max(1, end.timeIntervalSince(start))))
    let projected = elapsed > 0 ? amount / elapsed : amount

    let thresholds = Array(Set(budget.alertThresholds.filter { (1...100).contains($0) })).sorted()
    return thresholds.compactMap { threshold in
      let target = budget.limit * Double(threshold) / 100
      let actualReached = amount >= target
      let forecastReached = projected >= target
      let shouldAlert: Bool = switch budget.alertMode {
      case .actual: actualReached
      case .forecast: forecastReached
      case .either: actualReached || forecastReached
      }
      guard shouldAlert else { return nil }
      let key = "\(budget.id)|\(Int(start.timeIntervalSince1970))|\(threshold)"
      return UsageBudgetAlert(
        id: key,
        budgetName: budget.name,
        threshold: threshold,
        currentAmount: amount,
        projectedAmount: projected,
        metric: budget.metric,
        isForecast: !actualReached && forecastReached)
    }
  }

  private func estimatedCost(for events: [UsageEvent], profiles: [ModelCostProfile]) -> Double? {
    guard !events.isEmpty else { return nil }
    var total = 0.0
    for event in events {
      guard let model = event.model,
        let profile = profiles.first(where: { $0.matches(model: model) })
      else { return nil }
      let tokens = event.tokens
      total += Double(tokens.inputTokens ?? 0) / 1_000_000 * profile.inputCostPerMillion
      total += Double(tokens.outputTokens ?? 0) / 1_000_000 * profile.outputCostPerMillion
      total += Double(tokens.cachedInputTokens ?? 0) / 1_000_000
        * profile.cachedInputCostPerMillion
      total += Double(tokens.cacheCreationTokens ?? 0) / 1_000_000
        * (profile.cacheCreationCostPerMillion ?? profile.cachedInputCostPerMillion)
    }
    return total
  }
}

private extension UsageBudgetPeriod {
  var calendarComponent: Calendar.Component {
    switch self {
    case .day: .day
    case .week: .weekOfYear
    case .month: .month
    }
  }
}
