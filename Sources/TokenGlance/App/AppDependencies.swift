import Foundation
import SwiftUI
import TokenGlanceCore

@MainActor
final class AppDependencies: ObservableObject {
  let database = UsageDatabase()
  let settingsStore = SettingsStore()
  let aggregator = UsageAggregator()
  let pulseAnalyzer = UsagePulseAnalyzer()
  let modelEfficiencyAnalyzer = ModelEfficiencyAnalyzer()
  let projectUsageAnalyzer = ProjectUsageAnalyzer()
  let usageAnomalyAnalyzer = UsageAnomalyAnalyzer()
  let schemaDriftRadar = SchemaDriftRadar()
  let diagnosticsBuilder = DiagnosticsBuilder()
  let weeklyReportBuilder = WeeklyUsageReportBuilder()
  let reportArchive = LocalReportArchive()
  let updateRelaunchMonitor = UpdateRelaunchMonitor()
  let claudeTelemetryReceiver = ClaudeTelemetryReceiver()
  let collectors: [any UsageCollector]

  @Published var settings = AppSettings()
  @Published var events: [UsageEvent] = []
  @Published var summary: UsageSummary?
  @Published var menuBarSummary: UsageSummary?
  @Published var usagePulse = UsagePulse.empty
  @Published var modelEfficiencyRows: [ModelEfficiencyRow] = []
  @Published var projectUsageRows: [ProjectUsageRow] = []
  @Published var usageAnomalies: [UsageAnomaly] = []
  @Published var diagnosticsText = ""
  @Published var collectorDiagnostics: [CollectorDiagnostic] = []
  @Published var lastArchivedReportURL: URL?
  @Published var selectedPeriod: ReportingPeriod = .today
  @Published var selectedTool: ToolIdentifier?
  @Published var selectedModel: String?
  @Published var isRefreshing = false
  @Published var isLiveRefreshRunning = false
  @Published var lastRefresh: Date?

  private var hasStarted = false
  private var liveRefreshTask: Task<Void, Never>?

  private enum RefreshMode {
    case full
    case live
  }

  deinit {
    liveRefreshTask?.cancel()
    let receiver = claudeTelemetryReceiver
    Task { await receiver.stop() }
  }

  init() {
    collectors = [
      CodexCLICollector(),
      ClaudeCodeCollector(configurator: ClaudeCodeTelemetryConfigurator()),
      AntigravityCollector(),
    ]
  }

  func start() {
    guard !hasStarted else { return }
    hasStarted = true
    Task {
      do {
        settings = try await settingsStore.load()
        selectedPeriod = settings.defaultReportingPeriod
        try await database.open()
        _ = try? await claudeTelemetryReceiver.start()
        await refresh(mode: .full)
        configureLiveRefresh()
        updateRelaunchMonitor.start()
      } catch {
        diagnosticsText = Redactor().redact(error.localizedDescription)
      }
    }
  }

  func refresh() async {
    await refresh(mode: .full)
  }

  private func refresh(mode: RefreshMode) async {
    guard !isRefreshing else { return }
    isRefreshing = true
    defer { isRefreshing = false }

    var diagnostics: [CollectorDiagnostic] = []
    let cursors = (try? await database.collectionCursors()) ?? []
    let shouldUpdateDiagnostics = mode == .full
    for collector in collectors where settings.enabledCollectors.contains(collector.identifier) {
      var batch = CollectionBatch(events: [])
      do {
        batch = try await collector.collect(since: cursors)
        _ = try await database.importBatch(batch)
      } catch {
        if shouldUpdateDiagnostics {
          diagnostics.append(
            CollectorDiagnostic(
              identifier: collector.identifier,
              status: .parserError,
              sourceKind: .unsupported,
              parserVersion: "unknown",
              explanation: "Collection failed without exposing source content.",
              detectedVersion: nil,
              lastNonSensitiveError: Redactor().redact(error.localizedDescription)
            ))
        }
      }
      if shouldUpdateDiagnostics {
        let baseDiagnostic = await collector.diagnose()
        diagnostics.append(schemaDriftRadar.diagnose(base: baseDiagnostic, batch: batch))
      }
    }

    lastRefresh = Date()
    await loadMenuBarSummary()
    await loadSummary(animated: mode == .full)
    if shouldUpdateDiagnostics {
      collectorDiagnostics = diagnostics
      let report = await diagnosticsBuilder.build(
        database: database, collectorDiagnostics: diagnostics)
      diagnosticsText = report.text()
    }
  }

  func loadSummary(animated: Bool = true) async {
    let interval = aggregator.interval(for: selectedPeriod)
    do {
      events = try await database.fetchEvents(from: interval.start, to: interval.end)
      let nextSummary = aggregator.summarize(
        events: events,
        period: selectedPeriod,
        toolFilter: selectedTool,
        modelFilter: selectedModel)
      let efficiencyRows = modelEfficiencyAnalyzer.analyze(
        events: events,
        costProfiles: settings.modelCostProfiles)
      let projectRows = projectUsageAnalyzer.analyze(
        events: events,
        toolFilter: selectedTool,
        modelFilter: selectedModel,
        costProfiles: settings.modelCostProfiles)
      let anomalyRows = usageAnomalyAnalyzer.analyze(
        events: events,
        period: selectedPeriod,
        toolFilter: selectedTool,
        modelFilter: selectedModel)
      if animated {
        withAnimation(.snappy(duration: 0.25)) {
          summary = nextSummary
          modelEfficiencyRows = efficiencyRows
          projectUsageRows = projectRows
          usageAnomalies = anomalyRows
        }
      } else {
        summary = nextSummary
        modelEfficiencyRows = efficiencyRows
        projectUsageRows = projectRows
        usageAnomalies = anomalyRows
      }
    } catch {
      diagnosticsText = Redactor().redact(error.localizedDescription)
    }
  }

  func loadMenuBarSummary() async {
    let interval = aggregator.interval(for: .today)
    do {
      let todayEvents = try await database.fetchEvents(from: interval.start, to: interval.end)
      menuBarSummary = aggregator.summarize(events: todayEvents, period: .today)
      usagePulse = pulseAnalyzer.analyze(events: todayEvents)
    } catch {
      diagnosticsText = Redactor().redact(error.localizedDescription)
    }
  }

  func completeOnboarding() {
    settings.hasCompletedOnboarding = true
    Task { try? await settingsStore.save(settings) }
  }

  func saveSettings() {
    settings.liveRefreshIntervalSeconds = AppSettings.clampedLiveRefreshInterval(
      settings.liveRefreshIntervalSeconds)
    configureLiveRefresh()
    Task {
      try? await settingsStore.save(settings)
      await loadSummary()
    }
  }

  func deleteAllData() {
    Task {
      try? await database.deleteAllData()
      await loadMenuBarSummary()
      await loadSummary()
    }
  }

  func weeklyReportMarkdown() async -> String {
    let interval = aggregator.interval(for: .last30Days)
    do {
      let reportEvents = try await database.fetchEvents(from: interval.start, to: interval.end)
      return weeklyReportBuilder.markdown(events: reportEvents)
    } catch {
      return Redactor().redact(error.localizedDescription)
    }
  }

  func archiveWeeklyReport() async -> String {
    let markdown = await weeklyReportMarkdown()
    do {
      let url = try reportArchive.saveWeeklyReport(markdown)
      lastArchivedReportURL = url
      return markdown
    } catch {
      return Redactor().redact(error.localizedDescription)
    }
  }

  func importUsageMetadata(from url: URL) async {
    do {
      let batch = try await Task.detached(priority: .userInitiated) {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
          if hasAccess { url.stopAccessingSecurityScopedResource() }
        }
        let data = try Data(contentsOf: url)
        return try ManualUsageImportParser().parse(data, sourceName: url.lastPathComponent)
      }.value
      let inserted = try await database.importBatch(batch)
      lastRefresh = Date()
      await loadMenuBarSummary()
      await loadSummary()
      diagnosticsText =
        "Imported \(inserted) manual usage events. Invalid rows: \(batch.invalidRecords)."
    } catch {
      diagnosticsText = Redactor().redact(error.localizedDescription)
    }
  }

  func configureLiveRefresh() {
    liveRefreshTask?.cancel()
    liveRefreshTask = nil
    isLiveRefreshRunning = false

    guard settings.liveRefreshEnabled else { return }
    isLiveRefreshRunning = true
    let interval = AppSettings.clampedLiveRefreshInterval(settings.liveRefreshIntervalSeconds)

    liveRefreshTask = Task { [weak self] in
      while !Task.isCancelled {
        do {
          try await Task.sleep(for: .seconds(interval))
        } catch {
          break
        }
        await self?.refresh(mode: .live)
      }
      await MainActor.run {
        self?.isLiveRefreshRunning = false
      }
    }
  }
}
