import Charts
import SwiftUI
import TokenGlanceCore

struct DashboardView: View {
  @EnvironmentObject private var dependencies: AppDependencies
  @State private var mode: DashboardMode = .overview

  var body: some View {
    VStack(spacing: 0) {
      topBar
      Divider()
      content
    }
    .background(.regularMaterial)
    .task {
      if dependencies.summary == nil {
        await dependencies.refresh()
      }
    }
  }

  private var topBar: some View {
    HStack(spacing: 10) {
      Image(systemName: "chart.bar.xaxis")
        .font(.title3.weight(.semibold))
        .foregroundStyle(.tint)
        .frame(width: 28, height: 28)

      VStack(alignment: .leading, spacing: 1) {
        Text("TokenGlance")
          .font(.headline.weight(.semibold))
        HStack(spacing: 6) {
          LiveStatusDot(isRunning: dependencies.isLiveRefreshRunning)
          Text(lastRefreshText)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }

      Spacer()

      Picker("View", selection: $mode) {
        ForEach(DashboardMode.allCases) { mode in
          Image(systemName: mode.symbol).tag(mode)
        }
      }
      .labelsHidden()
      .pickerStyle(.segmented)
      .frame(width: 118)
      .accessibilityIdentifier("dashboard-mode-picker")

      Button {
        Task { await dependencies.refresh() }
      } label: {
        Image(
          systemName: dependencies.isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
      }
      .buttonStyle(.borderless)
      .help("Refresh")
      .accessibilityIdentifier("refresh-button")
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
  }

  @ViewBuilder
  private var content: some View {
    switch mode {
    case .overview:
      overview
    case .settings:
      SettingsView()
        .environmentObject(dependencies)
        .padding(14)
    case .diagnostics:
      diagnostics
    }
  }

  private var overview: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        periodStrip
        totalsPanel
        usageChart
        collectorModules
        breakdownColumns
      }
      .padding(14)
    }
  }

  private var periodStrip: some View {
    VStack(spacing: 8) {
      Picker("Period", selection: $dependencies.selectedPeriod) {
        ForEach(ReportingPeriod.allCases, id: \.self) { period in
          Text(period.displayName).tag(period)
        }
      }
      .pickerStyle(.segmented)
      .onChange(of: dependencies.selectedPeriod) { _, _ in
        Task { await dependencies.loadSummary() }
      }

      HStack(spacing: 8) {
        Picker(
          "Tool",
          selection: Binding(
            get: { dependencies.selectedTool },
            set: {
              dependencies.selectedTool = $0
              Task { await dependencies.loadSummary() }
            }
          )
        ) {
          Text("All tools").tag(Optional<ToolIdentifier>.none)
          Text("Codex").tag(Optional(ToolIdentifier.codexCLI))
          Text("Claude").tag(Optional(ToolIdentifier.claudeCode))
          Text("Antigravity").tag(Optional(ToolIdentifier.antigravity))
        }

        Picker(
          "Model",
          selection: Binding(
            get: { dependencies.selectedModel },
            set: {
              dependencies.selectedModel = $0
              Task { await dependencies.loadSummary() }
            }
          )
        ) {
          Text("All models").tag(Optional<String>.none)
          ForEach(Array(Set(dependencies.events.compactMap(\.model))).sorted(), id: \.self) {
            model in
            Text(model).tag(Optional(model))
          }
        }
      }
    }
  }

  private var totalsPanel: some View {
    let totals = dependencies.summary?.totals ?? TokenBreakdown()
    return HStack(alignment: .center, spacing: 14) {
      ZStack {
        Circle()
          .stroke(.quaternary, lineWidth: 8)
        Circle()
          .trim(from: 0, to: fillRatio(for: totals))
          .stroke(.tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
          .rotationEffect(.degrees(-90))
        VStack(spacing: 0) {
          Text(totals.calculatedTotal.formatted(.number.notation(.compactName)))
            .font(.title3.monospacedDigit().weight(.semibold))
          Text("tokens")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
      .frame(width: 96, height: 96)

      VStack(spacing: 8) {
        MetricRow(label: "Input", value: totals.inputTokens, color: .blue)
        MetricRow(label: "Output", value: totals.outputTokens, color: .green)
        MetricRow(label: "Cached", value: totals.cachedInputTokens, color: .purple)
        MetricRow(label: "Reasoning", value: totals.reasoningTokens, color: .orange)
      }
    }
    .padding(12)
    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
  }

  private var usageChart: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Label("Usage", systemImage: "waveform.path.ecg")
          .font(.headline)
        Spacer()
        Text(dependencies.summary?.accuracy.rawValue ?? UsageAccuracy.unavailable.rawValue)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      Chart(dependencies.summary?.buckets ?? []) { bucket in
        BarMark(
          x: .value("Time", bucket.start),
          y: .value("Tokens", bucket.tokens.calculatedTotal)
        )
        .foregroundStyle(Color.accentColor.gradient)
        .cornerRadius(3)
      }
      .chartXAxis(.automatic)
      .chartYAxis {
        AxisMarks(position: .leading) { value in
          AxisGridLine()
          AxisTick()
          AxisValueLabel {
            if let tokens = value.as(Int.self) {
              Text(TokenNumberFormat.compact(tokens))
            } else if let tokens = value.as(Double.self) {
              Text(TokenNumberFormat.compact(Int(tokens)))
            }
          }
        }
      }
      .frame(height: 136)
      .accessibilityIdentifier("usage-chart")
    }
    .padding(12)
    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
  }

  private var collectorModules: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Collectors", systemImage: "dot.radiowaves.left.and.right")
        .font(.headline)

      ForEach(CollectorIdentifier.allCases, id: \.self) { identifier in
        let diagnostic = dependencies.collectorDiagnostics.first { $0.identifier == identifier }
        CollectorModuleRow(
          name: identifier.displayName,
          status: diagnostic?.status ?? .sourceUnavailable,
          detail: diagnostic?.detectedVersion ?? "not detected",
          explanation: diagnostic?.explanation ?? "No diagnostic has been collected yet."
        )
      }
    }
    .padding(12)
    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
  }

  private var breakdownColumns: some View {
    HStack(alignment: .top, spacing: 10) {
      BreakdownList(
        title: "Tools",
        symbol: "hammer",
        rows: (dependencies.summary?.byTool ?? [:]).map {
          ($0.key.rawValue, $0.value.calculatedTotal)
        }
      )
      BreakdownList(
        title: "Models",
        symbol: "cpu",
        rows: (dependencies.summary?.byModel ?? [:]).map { ($0.key, $0.value.calculatedTotal) }
      )
    }
  }

  private var diagnostics: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Label("Diagnostics", systemImage: "stethoscope")
          .font(.headline)
        Spacer()
        Button {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(dependencies.diagnosticsText, forType: .string)
        } label: {
          Label("Copy", systemImage: "doc.on.doc")
        }
        .accessibilityIdentifier("copy-diagnostics-button")
      }

      ScrollView {
        Text(
          dependencies.diagnosticsText.isEmpty
            ? "Diagnostics are not available yet." : dependencies.diagnosticsText
        )
        .font(.system(.caption, design: .monospaced))
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
        .padding(10)
      }
      .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
    }
    .padding(14)
  }

  private func fillRatio(for tokens: TokenBreakdown) -> CGFloat {
    let input = CGFloat(tokens.inputTokens ?? 0)
    let output = CGFloat(tokens.outputTokens ?? 0)
    let total = max(CGFloat(tokens.calculatedTotal), 1)
    return min(max((input + output) / total, 0.08), 1)
  }

  private var lastRefreshText: String {
    guard let date = dependencies.lastRefresh else { return "Not refreshed yet" }
    return "Last refresh \(date.formatted(date: .omitted, time: .shortened))"
  }
}

private enum DashboardMode: CaseIterable, Identifiable {
  case overview
  case settings
  case diagnostics

  var id: Self { self }

  var symbol: String {
    switch self {
    case .overview: "chart.xyaxis.line"
    case .settings: "gearshape"
    case .diagnostics: "stethoscope"
    }
  }
}

private struct MetricRow: View {
  let label: String
  let value: Int?
  let color: Color

  var body: some View {
    HStack(spacing: 8) {
      Circle()
        .fill(color)
        .frame(width: 7, height: 7)
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)
      Spacer()
      Text((value ?? 0).formatted(.number.notation(.compactName)))
        .font(.caption.monospacedDigit().weight(.semibold))
    }
  }
}

private struct LiveStatusDot: View {
  let isRunning: Bool

  var body: some View {
    Circle()
      .fill(isRunning ? .green : .secondary)
      .frame(width: 6, height: 6)
      .overlay {
        if isRunning {
          Circle()
            .stroke(.green.opacity(0.35), lineWidth: 4)
            .scaleEffect(1.3)
        }
      }
      .accessibilityLabel(isRunning ? "Live refresh running" : "Live refresh disabled")
  }
}

private enum TokenNumberFormat {
  static func compact(_ value: Int) -> String {
    value.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
  }
}

private struct CollectorModuleRow: View {
  let name: String
  let status: CollectorStatus
  let detail: String
  let explanation: String

  var body: some View {
    HStack(spacing: 10) {
      Circle()
        .fill(statusColor)
        .frame(width: 8, height: 8)
      VStack(alignment: .leading, spacing: 1) {
        Text(name)
          .font(.caption.weight(.semibold))
        Text(explanation)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 1) {
        Text(status.rawValue)
          .font(.caption2.monospaced())
        Text(detail)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 4)
  }

  private var statusColor: Color {
    switch status {
    case .detected, .active: .green
    case .setupRequired, .waitingForData, .partialSupport: .orange
    case .notInstalled, .disabled: .secondary
    default: .red
    }
  }
}

private struct BreakdownList: View {
  let title: String
  let symbol: String
  let rows: [(String, Int)]

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      Label(title, systemImage: symbol)
        .font(.headline)
      if rows.isEmpty {
        Text("No exact usage")
          .foregroundStyle(.secondary)
          .font(.caption)
      } else {
        ForEach(rows.sorted { $0.1 > $1.1 }, id: \.0) { name, value in
          HStack {
            Text(name)
              .lineLimit(1)
            Spacer()
            Text(value.formatted(.number.notation(.compactName)))
              .monospacedDigit()
          }
          .font(.caption)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .padding(12)
    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
  }
}
