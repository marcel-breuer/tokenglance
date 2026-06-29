import Charts
import SwiftUI
import TokenGlanceCore
import UniformTypeIdentifiers

struct DashboardView: View {
  @EnvironmentObject private var dependencies: AppDependencies
  @State private var mode: DashboardMode = .overview
  @State private var isImportingUsageFile = false
  private var strings: AppStrings { AppStrings(dependencies.settings.language) }

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
    .fileImporter(
      isPresented: $isImportingUsageFile,
      allowedContentTypes: [.commaSeparatedText, .json, .plainText],
      allowsMultipleSelection: false,
      onCompletion: handleUsageImport)
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
          LiveStatusDot(isRunning: dependencies.isLiveRefreshRunning, strings: strings)
          Text(lastRefreshText)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }

      Spacer()

      Picker(strings.view, selection: $mode) {
        ForEach(DashboardMode.allCases) { mode in
          Image(systemName: mode.symbol).tag(mode)
        }
      }
      .labelsHidden()
      .pickerStyle(.segmented)
      .frame(width: 118)
      .accessibilityIdentifier("dashboard-mode-picker")

      Button {
        isImportingUsageFile = true
      } label: {
        Image(systemName: "tray.and.arrow.down")
      }
      .buttonStyle(.borderless)
      .help(strings.importUsageMetadata)
      .accessibilityIdentifier("usage-import-button")

      Button {
        Task {
          let report = await dependencies.archiveWeeklyReport()
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(report, forType: .string)
        }
      } label: {
        Image(systemName: "calendar.badge.clock")
      }
      .buttonStyle(.borderless)
      .help(strings.archiveWeeklyReport)
      .accessibilityIdentifier("weekly-report-button")

      Button {
        Task { await dependencies.refresh() }
      } label: {
        Image(
          systemName: dependencies.isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
      }
      .buttonStyle(.borderless)
      .help(strings.refresh)
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
        pulsePanel
        usageChart
        modelEfficiencyPanel
        collectorModules
        breakdownColumns
      }
      .padding(14)
    }
  }

  private var periodStrip: some View {
    VStack(spacing: 8) {
      Picker(strings.period, selection: $dependencies.selectedPeriod) {
        ForEach(ReportingPeriod.allCases, id: \.self) { period in
          Text(period.localizedName(using: strings)).tag(period)
        }
      }
      .pickerStyle(.segmented)
      .onChange(of: dependencies.selectedPeriod) { _, _ in
        Task { await dependencies.loadSummary() }
      }

      HStack(spacing: 8) {
        Picker(
          strings.tool,
          selection: Binding(
            get: { dependencies.selectedTool },
            set: {
              dependencies.selectedTool = $0
              Task { await dependencies.loadSummary() }
            }
          )
        ) {
          Text(strings.allTools).tag(Optional<ToolIdentifier>.none)
          ForEach(ToolIdentifier.allCases, id: \.self) { tool in
            Text(tool.displayName).tag(Optional(tool))
          }
        }

        Picker(
          strings.model,
          selection: Binding(
            get: { dependencies.selectedModel },
            set: {
              dependencies.selectedModel = $0
              Task { await dependencies.loadSummary() }
            }
          )
        ) {
          Text(strings.allModels).tag(Optional<String>.none)
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
          Text(strings.tokens)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
      .frame(width: 96, height: 96)

      VStack(spacing: 8) {
        MetricRow(label: strings.input, value: totals.inputTokens, color: .blue)
        MetricRow(label: strings.output, value: totals.outputTokens, color: .green)
        MetricRow(label: strings.cached, value: totals.cachedInputTokens, color: .purple)
        MetricRow(label: strings.reasoning, value: totals.reasoningTokens, color: .orange)
      }
    }
    .padding(12)
    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
  }

  private var pulsePanel: some View {
    let pulse = dependencies.usagePulse
    return HStack(spacing: 12) {
      WeatherBadge(weather: pulse.weather, strings: strings)
      VStack(alignment: .leading, spacing: 4) {
        Text(strings.burnRate)
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(strings.tokensPerHour(TokenNumberFormat.compact(pulse.burnRatePerHour)))
          .font(.headline.monospacedDigit().weight(.semibold))
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 4) {
        Text(strings.projectedToday)
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(TokenNumberFormat.compact(pulse.projectedTokensToday))
          .font(.headline.monospacedDigit().weight(.semibold))
      }
    }
    .padding(12)
    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
    .accessibilityIdentifier("usage-pulse-panel")
  }

  private var usageChart: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Label(strings.usage, systemImage: "waveform.path.ecg")
          .font(.headline)
        Spacer()
        Text((dependencies.summary?.accuracy ?? .unavailable).localizedName(using: strings))
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      Chart(dependencies.summary?.buckets ?? []) { bucket in
        BarMark(
          x: .value(strings.chartTime, bucket.start),
          y: .value(strings.chartTokens, bucket.tokens.calculatedTotal)
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
      Label(strings.collectors, systemImage: "dot.radiowaves.left.and.right")
        .font(.headline)

      ForEach(CollectorIdentifier.allCases, id: \.self) { identifier in
        let diagnostic = dependencies.collectorDiagnostics.first { $0.identifier == identifier }
        CollectorModuleRow(
          name: identifier.displayName,
          status: diagnostic?.status ?? .sourceUnavailable,
          statusText: (diagnostic?.status ?? .sourceUnavailable).localizedName(using: strings),
          detail: diagnostic?.detectedVersion ?? strings.notDetected,
          explanation: diagnostic?.explanation ?? strings.noDiagnostic
        )
      }
    }
    .padding(12)
    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
  }

  private var modelEfficiencyPanel: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Label(strings.modelEfficiency, systemImage: "gauge.with.dots.needle.67percent")
          .font(.headline)
        Spacer()
        if !dependencies.settings.modelCostProfiles.isEmpty {
          Text(strings.estimated)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }

      if dependencies.modelEfficiencyRows.isEmpty {
        Text(strings.noExactUsage)
          .foregroundStyle(.secondary)
          .font(.caption)
      } else {
        ForEach(Array(dependencies.modelEfficiencyRows.prefix(5))) { row in
          ModelEfficiencyRowView(row: row, strings: strings)
          if row.id != dependencies.modelEfficiencyRows.prefix(5).last?.id {
            Divider()
          }
        }
      }
    }
    .padding(12)
    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
    .accessibilityIdentifier("model-efficiency-panel")
  }

  private var breakdownColumns: some View {
    HStack(alignment: .top, spacing: 10) {
      BreakdownList(
        title: strings.tools,
        symbol: "hammer",
        rows: (dependencies.summary?.byTool ?? [:]).map {
          ($0.key.displayName, $0.value.calculatedTotal)
        },
        strings: strings
      )
      BreakdownList(
        title: strings.models,
        symbol: "cpu",
        rows: (dependencies.summary?.byModel ?? [:]).map { ($0.key, $0.value.calculatedTotal) },
        strings: strings
      )
    }
  }

  private var diagnostics: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Label(strings.diagnostics, systemImage: "stethoscope")
          .font(.headline)
        Spacer()
        Button {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(dependencies.diagnosticsText, forType: .string)
        } label: {
          Label(strings.copy, systemImage: "doc.on.doc")
        }
        .accessibilityIdentifier("copy-diagnostics-button")
      }

      ScrollView {
        Text(
          dependencies.diagnosticsText.isEmpty
            ? strings.diagnosticsUnavailable : dependencies.diagnosticsText
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
    guard let date = dependencies.lastRefresh else { return strings.notRefreshedYet }
    return strings.lastRefresh(date)
  }

  private func handleUsageImport(_ result: Result<[URL], Error>) {
    switch result {
    case .success(let urls):
      guard let url = urls.first else { return }
      Task { await dependencies.importUsageMetadata(from: url) }
    case .failure(let error):
      dependencies.diagnosticsText = Redactor().redact(error.localizedDescription)
    }
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
  let strings: AppStrings

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
      .accessibilityLabel(isRunning ? strings.liveRefreshRunning : strings.liveRefreshDisabled)
  }
}

private struct WeatherBadge: View {
  let weather: TokenWeather
  let strings: AppStrings

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Label(strings.tokenWeather, systemImage: symbol)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(weather.localizedName(using: strings))
        .font(.headline.weight(.semibold))
        .foregroundStyle(color)
    }
    .frame(minWidth: 92, alignment: .leading)
  }

  private var symbol: String {
    switch weather {
    case .calm: "cloud"
    case .active: "sun.max"
    case .stormy: "cloud.bolt"
    }
  }

  private var color: Color {
    switch weather {
    case .calm: .green
    case .active: .orange
    case .stormy: .red
    }
  }
}

private struct ModelEfficiencyRowView: View {
  let row: ModelEfficiencyRow
  let strings: AppStrings

  var body: some View {
    HStack(alignment: .center, spacing: 10) {
      VStack(alignment: .leading, spacing: 2) {
        Text(row.model)
          .font(.caption.weight(.semibold))
          .lineLimit(1)
        Text(
          "\(row.eventCount) events · \(strings.average) \(TokenNumberFormat.compact(row.averageTokensPerEvent))"
        )
        .font(.caption2)
        .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 2) {
        Text(TokenNumberFormat.compact(row.tokens.calculatedTotal))
          .font(.caption.monospacedDigit().weight(.semibold))
        Text(detailText)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
  }

  private var detailText: String {
    let cache = row.cacheShare.formatted(.percent.precision(.fractionLength(0...1)))
    let reasoning = row.reasoningShare.formatted(.percent.precision(.fractionLength(0...1)))
    let cost =
      row.estimatedCost.map {
        $0.formatted(.currency(code: "USD").precision(.fractionLength(2...4)))
      } ?? "n/a"
    return "cache \(cache) · reasoning \(reasoning) · \(cost)"
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
  let statusText: String
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
        Text(statusText)
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
  let strings: AppStrings

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      Label(title, systemImage: symbol)
        .font(.headline)
      if rows.isEmpty {
        Text(strings.noExactUsage)
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
