import Foundation

public enum MenuBarMetric: String, CaseIterable, Codable, Sendable {
  case totalToday
  case lastHour
  case inputToday
  case outputToday
  case iconOnly

  public var displayName: String {
    switch self {
    case .totalToday: "Total Tokens Today"
    case .lastHour: "Last Hour"
    case .inputToday: "Input Tokens Today"
    case .outputToday: "Output Tokens Today"
    case .iconOnly: "Icon Only"
    }
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
  public var menuBarMetric: MenuBarMetric
  public var defaultReportingPeriod: ReportingPeriod
  public var launchAtLogin: Bool
  public var retentionPeriod: RetentionPeriod
  public var hasCompletedOnboarding: Bool

  public init(
    enabledCollectors: Set<CollectorIdentifier> = Set(CollectorIdentifier.allCases),
    refreshIntervalSeconds: TimeInterval = 300,
    menuBarMetric: MenuBarMetric = .totalToday,
    defaultReportingPeriod: ReportingPeriod = .today,
    launchAtLogin: Bool = false,
    retentionPeriod: RetentionPeriod = .ninetyDays,
    hasCompletedOnboarding: Bool = false
  ) {
    self.enabledCollectors = enabledCollectors
    self.refreshIntervalSeconds = refreshIntervalSeconds
    self.menuBarMetric = menuBarMetric
    self.defaultReportingPeriod = defaultReportingPeriod
    self.launchAtLogin = launchAtLogin
    self.retentionPeriod = retentionPeriod
    self.hasCompletedOnboarding = hasCompletedOnboarding
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
