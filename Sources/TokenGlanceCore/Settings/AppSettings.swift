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
  case totalToday
  case sparklineToday
  case lastHour
  case inputToday
  case outputToday
  case iconOnly

  public var displayName: String {
    switch self {
    case .totalToday: "Total Tokens Today"
    case .sparklineToday: "Sparkline Today"
    case .lastHour: "Last Hour"
    case .inputToday: "Input Tokens Today"
    case .outputToday: "Output Tokens Today"
    case .iconOnly: "Icon Only"
    }
  }

  public static var selectableCases: [MenuBarMetric] {
    [.totalToday, .sparklineToday]
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

public struct AppSettings: Codable, Equatable, Sendable {
  public var enabledCollectors: Set<CollectorIdentifier>
  public var refreshIntervalSeconds: TimeInterval
  public var liveRefreshEnabled: Bool
  public var liveRefreshIntervalSeconds: TimeInterval
  public var menuBarMetric: MenuBarMetric
  public var defaultReportingPeriod: ReportingPeriod
  public var launchAtLogin: Bool
  public var retentionPeriod: RetentionPeriod
  public var language: AppLanguage
  public var hasCompletedOnboarding: Bool

  public init(
    enabledCollectors: Set<CollectorIdentifier> = Set(CollectorIdentifier.allCases),
    refreshIntervalSeconds: TimeInterval = 300,
    liveRefreshEnabled: Bool = true,
    liveRefreshIntervalSeconds: TimeInterval = 5,
    menuBarMetric: MenuBarMetric = .totalToday,
    defaultReportingPeriod: ReportingPeriod = .today,
    launchAtLogin: Bool = false,
    retentionPeriod: RetentionPeriod = .ninetyDays,
    language: AppLanguage = .system,
    hasCompletedOnboarding: Bool = false
  ) {
    self.enabledCollectors = enabledCollectors
    self.refreshIntervalSeconds = refreshIntervalSeconds
    self.liveRefreshEnabled = liveRefreshEnabled
    self.liveRefreshIntervalSeconds = liveRefreshIntervalSeconds
    self.menuBarMetric = menuBarMetric
    self.defaultReportingPeriod = defaultReportingPeriod
    self.launchAtLogin = launchAtLogin
    self.retentionPeriod = retentionPeriod
    self.language = language
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
      try container.decodeIfPresent(TimeInterval.self, forKey: .liveRefreshIntervalSeconds) ?? 5
    self.menuBarMetric =
      try container.decodeIfPresent(MenuBarMetric.self, forKey: .menuBarMetric) ?? .totalToday
    self.defaultReportingPeriod =
      try container.decodeIfPresent(ReportingPeriod.self, forKey: .defaultReportingPeriod) ?? .today
    self.launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
    self.retentionPeriod =
      try container.decodeIfPresent(RetentionPeriod.self, forKey: .retentionPeriod) ?? .ninetyDays
    self.language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .system
    self.hasCompletedOnboarding =
      try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
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
