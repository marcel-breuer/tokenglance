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
      MenuBarLabel(summary: dependencies.summary, metric: dependencies.settings.menuBarMetric)
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
