import Foundation

public enum AppLanguage: String, CaseIterable, Codable, Sendable {
  case system
  case german
  case english

  public var resolved: ResolvedAppLanguage {
    switch self {
    case .system:
      let preferredLanguage = Locale.preferredLanguages.first?.lowercased() ?? ""
      return preferredLanguage.hasPrefix("de") ? .german : .english
    case .german:
      return .german
    case .english:
      return .english
    }
  }
}

public enum ResolvedAppLanguage: Sendable {
  case german
  case english
}

public enum MenuBarMetric: String, CaseIterable, Codable, Sendable {
  case usageStrip
  case totalToday
  case sparklineToday
  case lastHour
  case inputToday
  case outputToday
  case iconOnly

  public var displayName: String {
    switch self {
    case .usageStrip: "Usage Strip"
    case .totalToday: "Total Tokens Today"
    case .sparklineToday: "Sparkline Today"
    case .lastHour: "Last Hour"
    case .inputToday: "Input Tokens Today"
    case .outputToday: "Output Tokens Today"
    case .iconOnly: "Icon Only"
    }
  }

  public static var selectableCases: [MenuBarMetric] {
    [.usageStrip, .totalToday, .sparklineToday]
  }
}

public enum RetentionPeriod: String, CaseIterable, Codable, Sendable {
  case sevenDays
  case thirtyDays
  case ninetyDays
  case oneYear
  case unlimited

  public var days: Int? {
    switch self {
    case .sevenDays: 7
    case .thirtyDays: 30
    case .ninetyDays: 90
    case .oneYear: 365
    case .unlimited: nil
    }
  }
}

public struct ModelCostProfile: Codable, Equatable, Identifiable, Sendable {
  public var id: String { modelPattern }
  public var modelPattern: String
  public var inputCostPerMillion: Double
  public var outputCostPerMillion: Double
  public var cachedInputCostPerMillion: Double
  public var cacheCreationCostPerMillion: Double?
  public var provider: ProviderIdentifier?
  public var currencyCode: String
  public var sourceURL: String?
  public var checkedOn: String?
  public var isPreset: Bool
  public var hasUserOverride: Bool
  public var catalogVersion: Int?

  public init(
    modelPattern: String,
    inputCostPerMillion: Double,
    outputCostPerMillion: Double,
    cachedInputCostPerMillion: Double = 0,
    cacheCreationCostPerMillion: Double? = nil,
    provider: ProviderIdentifier? = nil,
    currencyCode: String = "USD",
    sourceURL: String? = nil,
    checkedOn: String? = nil,
    isPreset: Bool = false,
    hasUserOverride: Bool = false,
    catalogVersion: Int? = nil
  ) {
    self.modelPattern = modelPattern
    self.inputCostPerMillion = inputCostPerMillion
    self.outputCostPerMillion = outputCostPerMillion
    self.cachedInputCostPerMillion = cachedInputCostPerMillion
    self.cacheCreationCostPerMillion = cacheCreationCostPerMillion
    self.provider = provider
    self.currencyCode = currencyCode
    self.sourceURL = sourceURL
    self.checkedOn = checkedOn
    self.isPreset = isPreset
    self.hasUserOverride = hasUserOverride
    self.catalogVersion = catalogVersion
  }

  private enum CodingKeys: String, CodingKey {
    case modelPattern, inputCostPerMillion, outputCostPerMillion, cachedInputCostPerMillion
    case cacheCreationCostPerMillion, provider, currencyCode, sourceURL, checkedOn, isPreset
    case hasUserOverride
    case catalogVersion
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    modelPattern = try container.decode(String.self, forKey: .modelPattern)
    inputCostPerMillion = try container.decode(Double.self, forKey: .inputCostPerMillion)
    outputCostPerMillion = try container.decode(Double.self, forKey: .outputCostPerMillion)
    cachedInputCostPerMillion = try container.decodeIfPresent(
      Double.self, forKey: .cachedInputCostPerMillion) ?? 0
    cacheCreationCostPerMillion = try container.decodeIfPresent(
      Double.self, forKey: .cacheCreationCostPerMillion)
    provider = try container.decodeIfPresent(ProviderIdentifier.self, forKey: .provider)
    currencyCode = try container.decodeIfPresent(String.self, forKey: .currencyCode) ?? "USD"
    sourceURL = try container.decodeIfPresent(String.self, forKey: .sourceURL)
    checkedOn = try container.decodeIfPresent(String.self, forKey: .checkedOn)
    isPreset = try container.decodeIfPresent(Bool.self, forKey: .isPreset) ?? false
    hasUserOverride = try container.decodeIfPresent(Bool.self, forKey: .hasUserOverride) ?? false
    catalogVersion = try container.decodeIfPresent(Int.self, forKey: .catalogVersion)
  }

  public func matches(model: String) -> Bool {
    let pattern = modelPattern.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !pattern.isEmpty else { return false }
    return model.localizedCaseInsensitiveContains(pattern)
  }
}

public enum ModelCostCatalog {
  public static let version = 1
  public static let checkedOn = "2026-10-24"
  public static let presets: [ModelCostProfile] = [
    ModelCostProfile(
      modelPattern: "gpt-6.1-sol", inputCostPerMillion: 1, outputCostPerMillion: 5,
      cachedInputCostPerMillion: 0.05, cacheCreationCostPerMillion: 1.25,
      provider: .openAI, sourceURL: "https://platform.openai.com/pricing/",
      checkedOn: checkedOn, isPreset: true, catalogVersion: version),
    ModelCostProfile(
      modelPattern: "gpt-6-astra", inputCostPerMillion: 5, outputCostPerMillion: 25,
      cachedInputCostPerMillion: 0.5, cacheCreationCostPerMillion: 6.25,
      provider: .openAI, sourceURL: "https://platform.openai.com/pricing/",
      checkedOn: checkedOn, isPreset: true, catalogVersion: version),
    ModelCostProfile(
      modelPattern: "claude-sonnet-5.5", inputCostPerMillion: 2, outputCostPerMillion: 10,
      cachedInputCostPerMillion: 0.1, cacheCreationCostPerMillion: 2.5,
      provider: .anthropic, sourceURL: "https://platform.claude.com/docs/en/about-claude/pricing",
      checkedOn: checkedOn, isPreset: true, catalogVersion: version),
    ModelCostProfile(
      modelPattern: "claude-opus-5.5", inputCostPerMillion: 4, outputCostPerMillion: 20,
      cachedInputCostPerMillion: 0.2, cacheCreationCostPerMillion: 5,
      provider: .anthropic, sourceURL: "https://platform.claude.com/docs/en/about-claude/pricing",
      checkedOn: checkedOn, isPreset: true, catalogVersion: version),
    ModelCostProfile(
      modelPattern: "gemini-3.8-flash", inputCostPerMillion: 0.75, outputCostPerMillion: 3.75,
      cachedInputCostPerMillion: 0.075, provider: .google,
      sourceURL: "https://ai.google.dev/gemini-api/docs/pricing",
      checkedOn: checkedOn, isPreset: true, catalogVersion: version),
  ]

  public static func updating(_ profiles: [ModelCostProfile]) -> [ModelCostProfile] {
    var result = profiles
    for preset in presets {
      if let index = result.firstIndex(where: {
        $0.modelPattern.caseInsensitiveCompare(preset.modelPattern) == .orderedSame
      }) {
        guard result[index].isPreset, !result[index].hasUserOverride else { continue }
        result[index] = preset
      } else {
        result.append(preset)
      }
    }
    return result
  }
}

public struct AppSettings: Codable, Equatable, Sendable {
  public static let defaultLiveRefreshIntervalSeconds: TimeInterval = 60
  public static let minimumLiveRefreshIntervalSeconds: TimeInterval = 30
  public static let maximumLiveRefreshIntervalSeconds: TimeInterval = 300

  public var enabledCollectors: Set<CollectorIdentifier>
  public var refreshIntervalSeconds: TimeInterval
  public var liveRefreshEnabled: Bool
  public var liveRefreshIntervalSeconds: TimeInterval
  public var menuBarMetric: MenuBarMetric
  public var defaultReportingPeriod: ReportingPeriod
  public var launchAtLogin: Bool
  public var retentionPeriod: RetentionPeriod
  public var language: AppLanguage
  public var modelCostProfiles: [ModelCostProfile]
  public var usageBudgets: [UsageBudget]
  public var budgetAlertsEnabled: Bool
  public var deliveredBudgetAlerts: Set<String>
  public var hasCompletedOnboarding: Bool

  public init(
    enabledCollectors: Set<CollectorIdentifier> = Set(CollectorIdentifier.allCases),
    refreshIntervalSeconds: TimeInterval = 300,
    liveRefreshEnabled: Bool = true,
    liveRefreshIntervalSeconds: TimeInterval = Self.defaultLiveRefreshIntervalSeconds,
    menuBarMetric: MenuBarMetric = .usageStrip,
    defaultReportingPeriod: ReportingPeriod = .today,
    launchAtLogin: Bool = false,
    retentionPeriod: RetentionPeriod = .ninetyDays,
    language: AppLanguage = .system,
    modelCostProfiles: [ModelCostProfile] = [],
    usageBudgets: [UsageBudget] = [],
    budgetAlertsEnabled: Bool = true,
    deliveredBudgetAlerts: Set<String> = [],
    hasCompletedOnboarding: Bool = false
  ) {
    self.enabledCollectors = enabledCollectors
    self.refreshIntervalSeconds = refreshIntervalSeconds
    self.liveRefreshEnabled = liveRefreshEnabled
    self.liveRefreshIntervalSeconds = Self.clampedLiveRefreshInterval(liveRefreshIntervalSeconds)
    self.menuBarMetric = menuBarMetric
    self.defaultReportingPeriod = defaultReportingPeriod
    self.launchAtLogin = launchAtLogin
    self.retentionPeriod = retentionPeriod
    self.language = language
    self.modelCostProfiles = modelCostProfiles
    self.usageBudgets = usageBudgets
    self.budgetAlertsEnabled = budgetAlertsEnabled
    self.deliveredBudgetAlerts = deliveredBudgetAlerts
    self.hasCompletedOnboarding = hasCompletedOnboarding
  }

  private enum CodingKeys: String, CodingKey {
    case enabledCollectors
    case refreshIntervalSeconds
    case liveRefreshEnabled
    case liveRefreshIntervalSeconds
    case menuBarMetric
    case defaultReportingPeriod
    case launchAtLogin
    case retentionPeriod
    case language
    case modelCostProfiles
    case usageBudgets
    case budgetAlertsEnabled
    case deliveredBudgetAlerts
    case hasCompletedOnboarding
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.enabledCollectors =
      try container.decodeIfPresent(Set<CollectorIdentifier>.self, forKey: .enabledCollectors)
      ?? Set(CollectorIdentifier.allCases)
    self.refreshIntervalSeconds =
      try container.decodeIfPresent(TimeInterval.self, forKey: .refreshIntervalSeconds) ?? 300
    self.liveRefreshEnabled =
      try container.decodeIfPresent(Bool.self, forKey: .liveRefreshEnabled) ?? true
    self.liveRefreshIntervalSeconds =
      Self.clampedLiveRefreshInterval(
        try container.decodeIfPresent(TimeInterval.self, forKey: .liveRefreshIntervalSeconds)
          ?? Self.defaultLiveRefreshIntervalSeconds)
    self.menuBarMetric =
      try container.decodeIfPresent(MenuBarMetric.self, forKey: .menuBarMetric) ?? .usageStrip
    self.defaultReportingPeriod =
      try container.decodeIfPresent(ReportingPeriod.self, forKey: .defaultReportingPeriod) ?? .today
    self.launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
    self.retentionPeriod =
      try container.decodeIfPresent(RetentionPeriod.self, forKey: .retentionPeriod) ?? .ninetyDays
    self.language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .system
    self.modelCostProfiles =
      try container.decodeIfPresent([ModelCostProfile].self, forKey: .modelCostProfiles) ?? []
    self.usageBudgets = try container.decodeIfPresent([UsageBudget].self, forKey: .usageBudgets) ?? []
    self.budgetAlertsEnabled = try container.decodeIfPresent(Bool.self, forKey: .budgetAlertsEnabled) ?? true
    self.deliveredBudgetAlerts = try container.decodeIfPresent(Set<String>.self, forKey: .deliveredBudgetAlerts) ?? []
    self.hasCompletedOnboarding =
      try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
  }

  public static func clampedLiveRefreshInterval(_ interval: TimeInterval) -> TimeInterval {
    min(max(interval, minimumLiveRefreshIntervalSeconds), maximumLiveRefreshIntervalSeconds)
  }
}

public actor SettingsStore {
  private let url: URL

  public init(
    url: URL = AppIdentity.applicationSupportDirectory.appendingPathComponent("settings.json")
  ) {
    self.url = url
  }

  public func load() throws -> AppSettings {
    guard FileManager.default.fileExists(atPath: url.path) else { return AppSettings() }
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(AppSettings.self, from: data)
  }

  public func save(_ settings: AppSettings) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let data = try JSONEncoder().encode(settings)
    try data.write(to: url, options: [.atomic])
  }
}
