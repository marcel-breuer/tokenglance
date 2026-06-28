import Foundation
import Testing

@testable import TokenGlanceCore

@Suite("Settings")
struct SettingsTests {
  @Test("Older settings decode with live refresh defaults")
  func olderSettingsDecodeWithLiveDefaults() throws {
    let json = """
      {
        "enabledCollectors": ["codex-cli"],
        "refreshIntervalSeconds": 300,
        "menuBarMetric": "totalToday",
        "defaultReportingPeriod": "today",
        "launchAtLogin": false,
        "retentionPeriod": "ninetyDays",
        "hasCompletedOnboarding": true
      }
      """
    let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
    #expect(settings.liveRefreshEnabled)
    #expect(settings.liveRefreshIntervalSeconds == 5)
    #expect(settings.enabledCollectors == [.codexCLI])
  }
}
