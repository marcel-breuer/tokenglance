import SwiftUI
import TokenGlanceCore

struct MenuBarLabel: View {
  let summary: UsageSummary?
  let metric: MenuBarMetric
  let language: AppLanguage
  private var strings: AppStrings { AppStrings(language) }

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: "chart.bar.xaxis")
      if metric != .iconOnly {
        Text(labelText)
          .font(.system(.body, design: .rounded).monospacedDigit().weight(.semibold))
        if metric == .totalToday {
          Text(strings.todayShort)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("TokenGlance \(accessibilityText)")
  }

  private var labelText: String {
    let tokens = summary?.totals ?? TokenBreakdown()
    let value: Int
    switch metric {
    case .totalToday:
      value = tokens.calculatedTotal
    case .lastHour:
      value = summary?.buckets.last?.tokens.calculatedTotal ?? 0
    case .inputToday:
      value = tokens.inputTokens ?? 0
    case .outputToday:
      value = tokens.outputTokens ?? 0
    case .iconOnly:
      value = 0
    }
    return value.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
  }

  private var accessibilityText: String {
    let tokens = summary?.totals.calculatedTotal ?? 0
    switch metric {
    case .lastHour:
      return strings.lastHourAccessibility(labelText)
    case .inputToday:
      return strings.inputTodayAccessibility(labelText)
    case .outputToday:
      return strings.outputTodayAccessibility(labelText)
    case .totalToday:
      return strings.totalTokensTodayAccessibility(tokens)
    case .iconOnly:
      return strings.menuBarIcon
    }
  }
}
