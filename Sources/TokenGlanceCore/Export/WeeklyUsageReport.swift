import Foundation

public struct WeeklyUsageReportBuilder: Sendable {
  private let aggregator: UsageAggregator
  private let calendar: Calendar

  public init(calendar: Calendar = .current) {
    self.calendar = calendar
    self.aggregator = UsageAggregator(calendar: calendar)
  }

  public func markdown(events: [UsageEvent], now: Date = Date()) -> String {
    let current = periodEnding(at: now)
    let previous = DateInterval(
      start: calendar.date(byAdding: .day, value: -7, to: current.start) ?? current.start,
      end: current.start)
    let currentEvents = events.filter { current.contains($0.timestamp) }
    let previousEvents = events.filter { previous.contains($0.timestamp) }
    let currentTotals = aggregator.combine(currentEvents.map(\.tokens))
    let previousTotals = aggregator.combine(previousEvents.map(\.tokens))
    let dailyRows = dailyTrendRows(events: currentEvents, interval: current)
    let peakDay = dailyRows.max { $0.tokens < $1.tokens }
    let peakHour = peakHour(events: currentEvents)
    let modelRows = topModelRows(events: currentEvents)
    let accuracy = currentEvents.contains { $0.accuracy != .exact } ? "partial" : "exact"

    var lines = [
      "# TokenGlance Weekly Report",
      "",
      "Period: \(dateRange(current))",
      "Accuracy: \(currentEvents.isEmpty ? "unavailable" : accuracy)",
      "",
      "## Summary",
      "",
      "- Total tokens: \(format(currentTotals.calculatedTotal))",
      "- Previous week: \(format(previousTotals.calculatedTotal))",
      "- Change: \(changeText(current: currentTotals.calculatedTotal, previous: previousTotals.calculatedTotal))",
      "- Cache share: \(percentage(cacheTokens(in: currentTotals), of: currentTotals.calculatedTotal))",
      "- Reasoning tokens: \(format(currentTotals.reasoningTokens ?? 0))",
      "",
      "## Peaks",
      "",
      "- Busiest day: \(peakDay.map { "\($0.label) with \(format($0.tokens)) tokens" } ?? "No usage")",
      "- Busiest hour: \(peakHour.map { "\($0.label) with \(format($0.tokens)) tokens" } ?? "No usage")",
      "",
      "## Daily Trend",
      "",
      "| Day | Tokens |",
      "| --- | ---: |",
    ]

    lines.append(contentsOf: dailyRows.map { "| \($0.label) | \(format($0.tokens)) |" })
    lines.append("")
    lines.append("## Top Models")
    lines.append("")
    lines.append("| Model | Tokens | Share |")
    lines.append("| --- | ---: | ---: |")
    if modelRows.isEmpty {
      lines.append("| No model metadata | 0 | 0% |")
    } else {
      lines.append(
        contentsOf: modelRows.map {
          "| \($0.model) | \(format($0.tokens)) | \(percentage($0.tokens, of: currentTotals.calculatedTotal)) |"
        })
    }
    lines.append("")
    lines.append("## Token Mix")
    lines.append("")
    lines.append("| Category | Tokens | Share |")
    lines.append("| --- | ---: | ---: |")
    lines.append(contentsOf: tokenMixRows(totals: currentTotals))

    return lines.joined(separator: "\n")
  }

  private func periodEnding(at now: Date) -> DateInterval {
    let today = calendar.startOfDay(for: now)
    let start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
    return DateInterval(
      start: start,
      end: now)
  }

  private func dailyTrendRows(events: [UsageEvent], interval: DateInterval) -> [TrendRow] {
    var rows: [TrendRow] = []
    var cursor = calendar.startOfDay(for: interval.start)
    let endDay = calendar.startOfDay(for: interval.end)
    while cursor <= endDay {
      let next = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
      let tokens =
        events
        .filter { $0.timestamp >= cursor && $0.timestamp < next }
        .map { $0.tokens.calculatedTotal }
        .reduce(0, +)
      rows.append(TrendRow(label: dayString(cursor), tokens: tokens))
      cursor = next
    }
    return rows
  }

  private func peakHour(events: [UsageEvent]) -> TrendRow? {
    let grouped = Dictionary(grouping: events) { event in
      calendar.dateInterval(of: .hour, for: event.timestamp)?.start ?? event.timestamp
    }
    return
      grouped
      .map { date, events in
        TrendRow(
          label: hourString(date),
          tokens: events.map { $0.tokens.calculatedTotal }.reduce(0, +))
      }
      .max { $0.tokens < $1.tokens }
  }

  private func topModelRows(events: [UsageEvent]) -> [ModelRow] {
    Dictionary(grouping: events) { $0.model ?? "Unknown model" }
      .map { model, events in
        ModelRow(model: model, tokens: events.map { $0.tokens.calculatedTotal }.reduce(0, +))
      }
      .sorted { first, second in
        if first.tokens == second.tokens { return first.model < second.model }
        return first.tokens > second.tokens
      }
      .prefix(5)
      .map(\.self)
  }

  private func tokenMixRows(totals: TokenBreakdown) -> [String] {
    let total = totals.calculatedTotal
    let rows: [(String, Int)] = [
      ("Input", totals.inputTokens ?? 0),
      ("Output", totals.outputTokens ?? 0),
      ("Cached input", totals.cachedInputTokens ?? 0),
      ("Cache creation", totals.cacheCreationTokens ?? 0),
      ("Reasoning", totals.reasoningTokens ?? 0),
      ("Other", totals.otherTokens ?? 0),
    ]
    return rows.map { category, tokens in
      "| \(category) | \(format(tokens)) | \(percentage(tokens, of: total)) |"
    }
  }

  private func cacheTokens(in totals: TokenBreakdown) -> Int {
    (totals.cachedInputTokens ?? 0) + (totals.cacheCreationTokens ?? 0)
  }

  private func changeText(current: Int, previous: Int) -> String {
    let delta = current - previous
    let sign = delta >= 0 ? "+" : "-"
    guard previous > 0 else {
      return "\(sign)\(format(abs(delta))) tokens"
    }
    return "\(sign)\(format(abs(delta))) tokens (\(percentage(delta, of: previous, signed: true)))"
  }

  private func percentage(_ value: Int, of total: Int, signed: Bool = false) -> String {
    guard total > 0 else { return signed ? "+0%" : "0%" }
    let ratio = (Double(value) / Double(total)) * 100
    let sign = signed && ratio > 0 ? "+" : ""
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 1
    return "\(sign)\(formatter.string(from: NSNumber(value: ratio)) ?? "0")%"
  }

  private func format(_ value: Int) -> String {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.numberStyle = .decimal
    return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
  }

  private func dateRange(_ interval: DateInterval) -> String {
    "\(dayString(interval.start)) to \(dayString(interval.end))"
  }

  private func dayString(_ date: Date) -> String {
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    return String(
      format: "%04d-%02d-%02d",
      components.year ?? 0,
      components.month ?? 0,
      components.day ?? 0)
  }

  private func hourString(_ date: Date) -> String {
    let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
    return String(
      format: "%04d-%02d-%02d %02d:00",
      components.year ?? 0,
      components.month ?? 0,
      components.day ?? 0,
      components.hour ?? 0)
  }
}

private struct TrendRow: Equatable {
  let label: String
  let tokens: Int
}

private struct ModelRow: Equatable {
  let model: String
  let tokens: Int
}
