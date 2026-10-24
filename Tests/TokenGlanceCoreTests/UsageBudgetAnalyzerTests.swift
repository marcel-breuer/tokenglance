import Foundation
import Testing

@testable import TokenGlanceCore

@Suite("Usage budgets")
struct UsageBudgetAnalyzerTests {
  @Test("Forecast alerts trigger on pace and actual alerts trigger on usage")
  func forecastAndActualThresholds() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = date("2026-10-24T12:00:00Z")
    let event = usageEvent(at: now.addingTimeInterval(-60), input: 600, model: "gpt-6.1-sol")
    let analyzer = UsageBudgetAnalyzer(calendar: calendar)
    let forecastBudget = UsageBudget(
      id: "monthly", period: .day, limit: 1_000, alertThresholds: [50, 80], alertMode: .forecast)

    let forecastAlerts = analyzer.analyze(
      budget: forecastBudget, events: [event], costProfiles: [], now: now)

    #expect(forecastAlerts.map(\.threshold) == [50, 80])
    #expect(forecastAlerts[0].isForecast == false)
    #expect(forecastAlerts[1].isForecast)

    let actualBudget = UsageBudget(
      id: "actual", period: .day, limit: 1_000, alertThresholds: [80], alertMode: .actual)
    #expect(analyzer.analyze(budget: actualBudget, events: [event], costProfiles: [], now: now).isEmpty)
  }

  @Test("Budget periods exclude earlier events and honor the calendar month")
  func periodBoundaries() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let analyzer = UsageBudgetAnalyzer(calendar: calendar)
    let now = date("2026-10-24T12:00:00Z")
    let priorMonth = usageEvent(at: date("2026-09-30T23:59:00Z"), input: 10_000, model: "gpt-6.1-sol")
    let currentMonth = usageEvent(at: date("2026-10-01T00:00:00Z"), input: 100, model: "gpt-6.1-sol")
    let budget = UsageBudget(id: "month", period: .month, limit: 1_000, alertThresholds: [50], alertMode: .actual)

    #expect(analyzer.analyze(budget: budget, events: [priorMonth, currentMonth], costProfiles: [], now: now).isEmpty)
  }

  @Test("Estimated-cost budgets remain unavailable for unmatched model prices")
  func missingCostProfileDoesNotUnderstateBudget() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = date("2026-10-24T12:00:00Z")
    let event = usageEvent(at: now, input: 1_000_000, model: "unknown")
    let budget = UsageBudget(
      id: "cost", period: .day, metric: .estimatedCost, limit: 1,
      alertThresholds: [50], alertMode: .actual)

    #expect(UsageBudgetAnalyzer(calendar: calendar).analyze(
      budget: budget, events: [event], costProfiles: [], now: now).isEmpty)
  }

  private func usageEvent(at date: Date, input: Int, model: String) -> UsageEvent {
    UsageEvent(
      id: UUID().uuidString, collector: .codexCLI, tool: .codexCLI, provider: .openAI,
      model: model, timestamp: date, tokens: TokenBreakdown(inputTokens: input),
      sessionIdentifierHash: nil, projectIdentifierHash: nil, sourceKind: .localJSONL,
      sourceFingerprint: "synthetic", accuracy: .exact, parserVersion: "test")
  }

  private func date(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
  }
}
