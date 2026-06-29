import SwiftUI
import TokenGlanceCore

@main
struct TokenGlanceApp: App {
  @StateObject private var dependencies: AppDependencies
  @StateObject private var statusItemController: StatusItemController

  init() {
    let dependencies = AppDependencies()
    _dependencies = StateObject(wrappedValue: dependencies)
    _statusItemController = StateObject(
      wrappedValue: StatusItemController(dependencies: dependencies))
  }

  var body: some Scene {
    Settings {
      SettingsView()
        .environmentObject(dependencies)
    }
  }
}
