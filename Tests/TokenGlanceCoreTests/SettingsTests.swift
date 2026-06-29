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
    #expect(settings.language == .system)
  }

  @Test("Legacy icon-only menu bar mode decodes but is not selectable")
  func legacyIconOnlyMenuBarModeDecodesButIsNotSelectable() throws {
    let json = """
      {
        "menuBarMetric": "iconOnly"
      }
      """
    let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
    #expect(settings.menuBarMetric == .iconOnly)
    #expect(!MenuBarMetric.selectableCases.contains(.iconOnly))
    #expect(MenuBarMetric.selectableCases.first == .totalToday)
  }

  @Test("Language setting decodes from persisted settings")
  func languageSettingDecodes() throws {
    let json = """
      {
        "language": "german"
      }
      """
    let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
    #expect(settings.language == .german)
  }
}
