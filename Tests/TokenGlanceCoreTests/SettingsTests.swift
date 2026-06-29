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
    #expect(settings.modelCostProfiles.isEmpty)
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

  @Test("Sparkline menu bar mode is selectable")
  func sparklineMenuBarModeIsSelectable() {
    #expect(MenuBarMetric.selectableCases.contains(.sparklineToday))
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

  @Test("Cost profiles decode from persisted settings")
  func costProfilesDecode() throws {
    let json = """
      {
        "modelCostProfiles": [
          {
            "modelPattern": "gpt",
            "inputCostPerMillion": 2.0,
            "outputCostPerMillion": 10.0,
            "cachedInputCostPerMillion": 0.5
          }
        ]
      }
      """
    let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
    #expect(settings.modelCostProfiles.count == 1)
    #expect(settings.modelCostProfiles[0].matches(model: "gpt-5"))
  }
}
