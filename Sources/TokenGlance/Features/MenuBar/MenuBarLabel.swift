import SwiftUI
import TokenGlanceCore

struct MenuBarLabel: View {
  let summary: UsageSummary?
  let metric: MenuBarMetric

  var body: some View {
    Label(labelText, systemImage: "chart.bar.xaxis")
      .accessibilityLabel("TokenGlance \(labelText)")
  }

  private var labelText: String {
    guard metric != .iconOnly else { return "" }
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
    return value.formatted(.number.notation(.compactName))
  }
}
