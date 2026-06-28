import SwiftUI
import TokenGlanceCore

@main
struct TokenGlanceApp: App {
  @StateObject private var dependencies = AppDependencies()

  var body: some Scene {
    MenuBarExtra {
      DashboardView()
        .environmentObject(dependencies)
        .frame(width: 460, height: 640)
        .task {
          if dependencies.summary == nil {
            dependencies.start()
          }
        }
    } label: {
      MenuBarLabel(
        summary: dependencies.menuBarSummary,
        metric: dependencies.settings.menuBarMetric,
        language: dependencies.settings.language
      )
      .task {
        dependencies.start()
      }
    }
    .menuBarExtraStyle(.window)

    Settings {
      SettingsView()
        .environmentObject(dependencies)
    }
  }
}
