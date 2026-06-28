import Charts
import SwiftUI
import TokenGlanceCore

struct DashboardView: View {
  @EnvironmentObject private var dependencies: AppDependencies

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      header
      filters
      summary
      chart
      toolBreakdown
      modelBreakdown
      collectorStatus
      actions
    }
    .padding(16)
    .task { await dependencies.loadSummary() }
  }

  private var header: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text("TokenGlance")
          .font(.title2.weight(.semibold))
        Text(lastRefreshText)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Button {
        Task { await dependencies.refresh() }
      } label: {
        Image(
          systemName: dependencies.isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
      }
      .help("Refresh")
      .accessibilityIdentifier("refresh-button")
    }
  }

  private var filters: some View {
    VStack(spacing: 8) {
      Picker("Period", selection: $dependencies.selectedPeriod) {
        ForEach(ReportingPeriod.allCases, id: \.self) { period in
          Text(period.displayName).tag(period)
        }
      }
      .pickerStyle(.segmented)
      .onChange(of: dependencies.selectedPeriod) { _, _ in Task { await dependencies.loadSummary() }
      }

      HStack {
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
          Text("Codex CLI").tag(Optional(ToolIdentifier.codexCLI))
          Text("Claude Code").tag(Optional(ToolIdentifier.claudeCode))
          Text("Gemini CLI").tag(Optional(ToolIdentifier.geminiCLI))
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

  private var summary: some View {
    let totals = dependencies.summary?.totals ?? TokenBreakdown()
    return Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
      GridRow {
        metric("Total", totals.calculatedTotal)
        metric("Input", totals.inputTokens)
        metric("Output", totals.outputTokens)
      }
      GridRow {
        metric("Cached", totals.cachedInputTokens)
        metric("Cache create", totals.cacheCreationTokens)
        metric("Reasoning", totals.reasoningTokens)
      }
    }
    .padding(10)
    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
  }

  private func metric(_ title: String, _ value: Int?) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title).font(.caption).foregroundStyle(.secondary)
      Text((value ?? 0).formatted(.number.notation(.compactName)))
        .font(.headline.monospacedDigit())
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var chart: some View {
    Chart(dependencies.summary?.buckets ?? []) { bucket in
      BarMark(
        x: .value("Time", bucket.start),
        y: .value("Tokens", bucket.tokens.calculatedTotal)
      )
      .foregroundStyle(.blue)
    }
    .frame(height: 150)
    .accessibilityIdentifier("usage-chart")
  }

  private var toolBreakdown: some View {
    BreakdownList(
      title: "Tools",
      rows: (dependencies.summary?.byTool ?? [:]).map {
        ($0.key.rawValue, $0.value.calculatedTotal)
      })
  }

  private var modelBreakdown: some View {
    BreakdownList(
      title: "Models",
      rows: (dependencies.summary?.byModel ?? [:]).map { ($0.key, $0.value.calculatedTotal) })
  }

  private var collectorStatus: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Collectors").font(.headline)
      ForEach(dependencies.collectorDiagnostics, id: \.identifier) { diagnostic in
        HStack {
          Text(diagnostic.identifier.displayName)
          Spacer()
          Text(diagnostic.status.rawValue)
            .foregroundStyle(
              diagnostic.status == .detected || diagnostic.status == .active ? .green : .secondary)
        }
        .font(.caption)
        .help(diagnostic.explanation)
      }
    }
  }

  private var actions: some View {
    HStack {
      Button("Settings") { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) }
      Button("Diagnostics") {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(dependencies.diagnosticsText, forType: .string)
      }
      Spacer()
      Button("Quit") { NSApp.terminate(nil) }
    }
  }

  private var lastRefreshText: String {
    guard let date = dependencies.lastRefresh else { return "Not refreshed yet" }
    return "Last refresh \(date.formatted(date: .omitted, time: .shortened))"
  }
}

private struct BreakdownList: View {
  let title: String
  let rows: [(String, Int)]

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title).font(.headline)
      if rows.isEmpty {
        Text("No exact usage collected for this period.")
          .foregroundStyle(.secondary)
          .font(.caption)
      } else {
        ForEach(rows.sorted { $0.1 > $1.1 }, id: \.0) { name, value in
          HStack {
            Text(name)
            Spacer()
            Text(value.formatted(.number.notation(.compactName))).monospacedDigit()
          }
          .font(.caption)
        }
      }
    }
  }
}
