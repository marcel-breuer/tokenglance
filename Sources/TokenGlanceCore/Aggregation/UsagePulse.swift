import Foundation

public enum TokenWeather: String, Codable, Equatable, Sendable {
  case calm
  case active
  case stormy
}

public struct UsagePulse: Equatable, Sendable {
  public let tokensLastHour: Int
  public let burnRatePerHour: Int
  public let projectedTokensToday: Int
  public let dayAveragePerHour: Int
  public let weather: TokenWeather

  public static let empty = UsagePulse(
    tokensLastHour: 0,
    burnRatePerHour: 0,
    projectedTokensToday: 0,
    dayAveragePerHour: 0,
    weather: .calm)
}

public struct UsagePulseAnalyzer: Sendable {
  private let calendar: Calendar
  private let aggregator: UsageAggregator

  public init(calendar: Calendar = .current) {
    self.calendar = calendar
    self.aggregator = UsageAggregator(calendar: calendar)
  }

  public func analyze(events: [UsageEvent], now: Date = Date()) -> UsagePulse {
    let today = aggregator.interval(for: .today, now: now)
    let hourStart = now.addingTimeInterval(-60 * 60)
    let todayEvents = events.filter { today.contains($0.timestamp) }
    let tokensToday = aggregator.combine(todayEvents.map(\.tokens)).calculatedTotal
    let tokensLastHour =
      todayEvents
      .filter { $0.timestamp >= hourStart && $0.timestamp < now }
      .map { $0.tokens.calculatedTotal }
      .reduce(0, +)
    let elapsedHours = max(now.timeIntervalSince(today.start) / 3600, 0.25)
    let dayAverage = Int((Double(tokensToday) / elapsedHours).rounded())
    let projection = Int((Double(tokensToday) / elapsedHours * 24).rounded())

    return UsagePulse(
      tokensLastHour: tokensLastHour,
      burnRatePerHour: tokensLastHour,
      projectedTokensToday: projection,
      dayAveragePerHour: dayAverage,
      weather: weather(burnRatePerHour: tokensLastHour, dayAveragePerHour: dayAverage))
  }

  private func weather(burnRatePerHour: Int, dayAveragePerHour: Int) -> TokenWeather {
    guard burnRatePerHour > 0 else { return .calm }
    if burnRatePerHour >= max(dayAveragePerHour * 2, 10_000) {
      return .stormy
    }
    if burnRatePerHour >= max(Int(Double(dayAveragePerHour) * 0.75), 1_000) {
      return .active
    }
    return .calm
  }
}
