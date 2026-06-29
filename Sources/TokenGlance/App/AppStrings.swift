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
