import Foundation
import TokenGlanceCore

struct AppStrings {
  let language: ResolvedAppLanguage

  init(_ selection: AppLanguage) {
    language = selection.resolved
  }

  var menuBarMetric: String { pick(de: "Menüleistenanzeige", en: "Menu bar metric") }
  var defaultPeriod: String { pick(de: "Standardzeitraum", en: "Default period") }
  var retention: String { pick(de: "Aufbewahrung", en: "Retention") }
  var languageSetting: String { pick(de: "Sprache", en: "Language") }
  var launchAtLogin: String { pick(de: "Beim Anmelden starten", en: "Launch at login") }
  var liveUpdates: String { pick(de: "Live-Aktualisierung", en: "Live Updates") }
  var liveRefresh: String { pick(de: "Live aktualisieren", en: "Live refresh") }
  var collectors: String { pick(de: "Sammler", en: "Collectors") }
  var data: String { pick(de: "Daten", en: "Data") }
  var deleteAllLocalUsageData: String {
    pick(de: "Alle lokalen Nutzungsdaten löschen", en: "Delete all local usage data")
  }
  var dataStoredUnder: String {
    pick(
      de: "Daten werden unter ~/Library/Application Support/TokenGlance gespeichert.",
      en: "Data is stored under ~/Library/Application Support/TokenGlance.")
  }
  var autoRefreshDescription: String {
    pick(
      de:
        "TokenGlance aktualisiert automatisch und zählt nur exakte Metadaten, nachdem ein Tool sie lokal geschrieben hat.",
      en:
        "TokenGlance refreshes automatically and only counts exact metadata after a tool writes it locally."
    )
  }
  var view: String { pick(de: "Ansicht", en: "View") }
  var refresh: String { pick(de: "Aktualisieren", en: "Refresh") }
  var importUsageMetadata: String {
    pick(de: "Nutzungsmetadaten importieren", en: "Import usage metadata")
  }
  var period: String { pick(de: "Zeitraum", en: "Period") }
  var tool: String { pick(de: "Tool", en: "Tool") }
  var model: String { pick(de: "Modell", en: "Model") }
  var allTools: String { pick(de: "Alle Tools", en: "All tools") }
  var allModels: String { pick(de: "Alle Modelle", en: "All models") }
  var tokens: String { pick(de: "Tokens", en: "tokens") }
  var input: String { pick(de: "Eingabe", en: "Input") }
  var output: String { pick(de: "Ausgabe", en: "Output") }
  var cached: String { pick(de: "Cache", en: "Cached") }
  var reasoning: String { pick(de: "Reasoning", en: "Reasoning") }
  var usage: String { pick(de: "Nutzung", en: "Usage") }
  var tokenWeather: String { pick(de: "Token-Wetter", en: "Token Weather") }
  var burnRate: String { pick(de: "Burn Rate", en: "Burn Rate") }
  var projectedToday: String { pick(de: "Prognose heute", en: "Projected Today") }
  var chartTime: String { pick(de: "Zeit", en: "Time") }
  var chartTokens: String { pick(de: "Tokens", en: "Tokens") }
  var notDetected: String { pick(de: "nicht erkannt", en: "not detected") }
  var noDiagnostic: String {
    pick(de: "Noch keine Diagnose erhoben.", en: "No diagnostic has been collected yet.")
  }
  var tools: String { pick(de: "Tools", en: "Tools") }
  var models: String { pick(de: "Modelle", en: "Models") }
  var diagnostics: String { pick(de: "Diagnose", en: "Diagnostics") }
  var copy: String { pick(de: "Kopieren", en: "Copy") }
  var weeklyReport: String { pick(de: "Wochenbericht", en: "Weekly report") }
  var archiveWeeklyReport: String {
    pick(de: "Wochenbericht archivieren", en: "Archive weekly report")
  }
  var modelEfficiency: String { pick(de: "Modell-Effizienz", en: "Model Efficiency") }
  var costProfiles: String { pick(de: "Kostenprofile", en: "Cost Profiles") }
  var addCostProfile: String { pick(de: "Kostenprofil hinzufügen", en: "Add cost profile") }
  var modelPattern: String { pick(de: "Modellmuster", en: "Model pattern") }
  var inputCost: String { pick(de: "Input $/M", en: "Input $/M") }
  var outputCost: String { pick(de: "Output $/M", en: "Output $/M") }
  var cachedCost: String { pick(de: "Cache $/M", en: "Cache $/M") }
  var estimated: String { pick(de: "geschätzt", en: "estimated") }
  var average: String { pick(de: "Ø", en: "avg") }
  var diagnosticsUnavailable: String {
    pick(de: "Diagnose ist noch nicht verfügbar.", en: "Diagnostics are not available yet.")
  }
  var notRefreshedYet: String {
    pick(de: "Noch nicht aktualisiert", en: "Not refreshed yet")
  }
  var liveRefreshRunning: String {
    pick(de: "Live-Aktualisierung läuft", en: "Live refresh running")
  }
  var liveRefreshDisabled: String {
    pick(de: "Live-Aktualisierung deaktiviert", en: "Live refresh disabled")
  }
  var noExactUsage: String { pick(de: "Keine exakte Nutzung", en: "No exact usage") }
  var todayShort: String { pick(de: "heute", en: "today") }
  var menuBarIcon: String { pick(de: "Menüleistensymbol", en: "menu bar icon") }
  var quitTokenGlance: String { pick(de: "TokenGlance beenden", en: "Quit TokenGlance") }
  var onboardingPrivacy: String {
    pick(
      de:
        "Nutzungsmetadaten werden lokal verarbeitet. TokenGlance lädt keine Nutzungsdaten, Prompts, Antworten, Quellcode oder Zugangsdaten hoch.",
      en:
        "Usage metadata is processed locally. TokenGlance does not upload usage data, prompts, responses, source code, or credentials."
    )
  }
  var onboardingCollectors: String {
    pick(
      de:
        "Sammler lesen nur verifizierte Token-Metadaten und können einzeln in den Einstellungen deaktiviert werden.",
      en:
        "Collectors read only verified token metadata and can be disabled individually in Settings."
    )
  }
  var continueButton: String { pick(de: "Weiter", en: "Continue") }

  func everySeconds(_ seconds: Int) -> String {
    pick(de: "Alle \(seconds) Sekunden", en: "Every \(seconds) seconds")
  }

  func lastRefresh(_ date: Date) -> String {
    let time = date.formatted(date: .omitted, time: .shortened)
    return pick(de: "Zuletzt aktualisiert \(time)", en: "Last refresh \(time)")
  }

  func totalTokensTodayAccessibility(_ tokens: Int) -> String {
    pick(
      de: "\(tokens.formatted()) Tokens heute insgesamt",
      en: "\(tokens.formatted()) total tokens today")
  }

  func tokenSparklineTodayAccessibility(_ tokens: Int) -> String {
    pick(
      de: "Tokenverlauf heute, \(tokens.formatted()) Tokens insgesamt",
      en: "Token usage sparkline today, \(tokens.formatted()) total tokens")
  }

  func lastHourAccessibility(_ label: String) -> String {
    pick(de: "\(label) Tokens in der letzten Stunde", en: "\(label) tokens in the last hour")
  }

  func inputTodayAccessibility(_ label: String) -> String {
    pick(de: "\(label) Eingabe-Tokens heute", en: "\(label) input tokens today")
  }

  func outputTodayAccessibility(_ label: String) -> String {
    pick(de: "\(label) Ausgabe-Tokens heute", en: "\(label) output tokens today")
  }

  func tokensPerHour(_ label: String) -> String {
    pick(de: "\(label) Tokens/h", en: "\(label) tokens/h")
  }

  func projectedTokensToday(_ label: String) -> String {
    pick(de: "\(label) Tokens heute prognostiziert", en: "\(label) projected tokens today")
  }

  func menuBarPulseTooltip(totalTokens: Int, pulse: UsagePulse) -> String {
    let burnRate = compactTokens(pulse.burnRatePerHour)
    let projection = compactTokens(pulse.projectedTokensToday)
    return pick(
      de:
        "\(totalTokens.formatted()) Tokens heute\nWetter: \(pulse.weather.localizedName(using: self))\nBurn Rate: \(burnRate) Tokens/h\nPrognose: \(projection)",
      en:
        "\(totalTokens.formatted()) total tokens today\nWeather: \(pulse.weather.localizedName(using: self))\nBurn rate: \(burnRate) tokens/h\nProjection: \(projection)"
    )
  }

  func menuBarAnalyticsTooltip(totalTokens: Int, pulse: UsagePulse, summary: UsageSummary?)
    -> String
  {
    let base = menuBarPulseTooltip(totalTokens: totalTokens, pulse: pulse)
    let peak = peakHourText(summary)
    let topModel = topModelText(summary)
    let cache = cacheShareText(summary?.totals)
    return pick(
      de: "\(base)\nPeak: \(peak)\nTop-Modell: \(topModel)\nCache-Anteil: \(cache)",
      en: "\(base)\nPeak: \(peak)\nTop model: \(topModel)\nCache share: \(cache)"
    )
  }

  func costProfileDescription(_ count: Int) -> String {
    pick(
      de: count == 0
        ? "Füge lokale Preisprofile hinzu, um Kosten in Effizienzansichten zu schätzen."
        : "\(count) lokale Preisprofile aktiv.",
      en: count == 0
        ? "Add local price profiles to estimate costs in efficiency views."
        : "\(count) local price profiles active."
    )
  }

  private func compactTokens(_ value: Int) -> String {
    value.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
  }

  private func peakHourText(_ summary: UsageSummary?) -> String {
    guard
      let bucket = summary?.buckets.max(by: {
        $0.tokens.calculatedTotal < $1.tokens.calculatedTotal
      }), bucket.tokens.calculatedTotal > 0
    else { return pick(de: "keine Nutzung", en: "no usage") }
    let time = bucket.start.formatted(date: .omitted, time: .shortened)
    return "\(time), \(compactTokens(bucket.tokens.calculatedTotal))"
  }

  private func topModelText(_ summary: UsageSummary?) -> String {
    guard
      let row = summary?.byModel.max(by: { $0.value.calculatedTotal < $1.value.calculatedTotal })
    else { return pick(de: "kein Modell", en: "no model") }
    return "\(row.key) \(compactTokens(row.value.calculatedTotal))"
  }

  private func cacheShareText(_ totals: TokenBreakdown?) -> String {
    guard let totals else { return "0%" }
    let total = totals.calculatedTotal
    guard total > 0 else { return "0%" }
    let cached = (totals.cachedInputTokens ?? 0) + (totals.cacheCreationTokens ?? 0)
    let share = Double(cached) / Double(total)
    return share.formatted(.percent.precision(.fractionLength(0...1)))
  }

  func pick(de: String, en: String) -> String {
    switch language {
    case .german: de
    case .english: en
    }
  }
}

extension AppLanguage {
  func localizedName(using strings: AppStrings) -> String {
    switch self {
    case .system:
      strings.pick(de: "Systemsprache", en: "System language")
    case .german:
      "Deutsch"
    case .english:
      "English"
    }
  }
}

extension MenuBarMetric {
  func localizedName(using strings: AppStrings) -> String {
    switch self {
    case .usageStrip:
      strings.pick(de: "Nutzungsstreifen", en: "Usage Strip")
    case .totalToday:
      strings.pick(de: "Tokens heute gesamt", en: "Total Tokens Today")
    case .sparklineToday:
      strings.pick(de: "Verlauf heute", en: "Sparkline Today")
    case .lastHour:
      strings.pick(de: "Letzte Stunde", en: "Last Hour")
    case .inputToday:
      strings.pick(de: "Eingabe-Tokens heute", en: "Input Tokens Today")
    case .outputToday:
      strings.pick(de: "Ausgabe-Tokens heute", en: "Output Tokens Today")
    case .iconOnly:
      strings.pick(de: "Nur Symbol", en: "Icon Only")
    }
  }
}

extension ReportingPeriod {
  func localizedName(using strings: AppStrings) -> String {
    switch self {
    case .today:
      strings.pick(de: "Heute", en: "Today")
    case .last24Hours:
      strings.pick(de: "Letzte 24 Stunden", en: "Last 24 Hours")
    case .last7Days:
      strings.pick(de: "Letzte 7 Tage", en: "Last 7 Days")
    case .last30Days:
      strings.pick(de: "Letzte 30 Tage", en: "Last 30 Days")
    }
  }
}

extension RetentionPeriod {
  func localizedName(using strings: AppStrings) -> String {
    switch self {
    case .sevenDays:
      strings.pick(de: "7 Tage", en: "7 days")
    case .thirtyDays:
      strings.pick(de: "30 Tage", en: "30 days")
    case .ninetyDays:
      strings.pick(de: "90 Tage", en: "90 days")
    case .oneYear:
      strings.pick(de: "1 Jahr", en: "1 year")
    case .unlimited:
      strings.pick(de: "Unbegrenzt", en: "Unlimited")
    }
  }
}

extension UsageAccuracy {
  func localizedName(using strings: AppStrings) -> String {
    switch self {
    case .exact:
      strings.pick(de: "exakt", en: "exact")
    case .partial:
      strings.pick(de: "teilweise", en: "partial")
    case .unavailable:
      strings.pick(de: "nicht verfügbar", en: "unavailable")
    }
  }
}

extension TokenWeather {
  func localizedName(using strings: AppStrings) -> String {
    switch self {
    case .calm:
      strings.pick(de: "ruhig", en: "calm")
    case .active:
      strings.pick(de: "aktiv", en: "active")
    case .stormy:
      strings.pick(de: "stürmisch", en: "stormy")
    }
  }
}

extension CollectorStatus {
  func localizedName(using strings: AppStrings) -> String {
    switch self {
    case .detected:
      strings.pick(de: "erkannt", en: "detected")
    case .active:
      strings.pick(de: "aktiv", en: "active")
    case .disabled:
      strings.pick(de: "deaktiviert", en: "disabled")
    case .notInstalled:
      strings.pick(de: "nicht installiert", en: "not installed")
    case .waitingForData:
      strings.pick(de: "wartet auf Daten", en: "waiting for data")
    case .setupRequired:
      strings.pick(de: "Einrichtung nötig", en: "setup required")
    case .permissionDenied:
      strings.pick(de: "Zugriff verweigert", en: "permission denied")
    case .unsupportedVersion:
      strings.pick(de: "Version nicht unterstützt", en: "unsupported version")
    case .unsupportedSchema:
      strings.pick(de: "Schema nicht unterstützt", en: "unsupported schema")
    case .partialSupport:
      strings.pick(de: "teilweise unterstützt", en: "partial support")
    case .parserError:
      strings.pick(de: "Parserfehler", en: "parser error")
    case .sourceUnavailable:
      strings.pick(de: "Quelle nicht verfügbar", en: "source unavailable")
    }
  }
}
