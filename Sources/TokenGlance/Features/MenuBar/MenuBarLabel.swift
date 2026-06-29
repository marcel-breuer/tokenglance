import SwiftUI
import TokenGlanceCore

struct MenuBarLabel: View {
  let summary: UsageSummary?
  let language: AppLanguage
  private var strings: AppStrings { AppStrings(language) }

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: "chart.bar.xaxis")
      Text(labelText)
        .font(.system(.body, design: .rounded).monospacedDigit().weight(.semibold))
      Text(strings.todayShort)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("TokenGlance \(accessibilityText)")
  }

  private var labelText: String {
    let totalTokensToday = summary?.totals.calculatedTotal ?? 0
    return totalTokensToday.formatted(
      .number.notation(.compactName).precision(.fractionLength(0...1)))
  }

  private var accessibilityText: String {
    let tokens = summary?.totals.calculatedTotal ?? 0
    return strings.totalTokensTodayAccessibility(tokens)
  }
}
