import ServiceManagement
import SwiftUI
import TokenGlanceCore

struct SettingsView: View {
  @EnvironmentObject private var dependencies: AppDependencies

  var body: some View {
    Form {
      Picker("Menu bar metric", selection: $dependencies.settings.menuBarMetric) {
        ForEach(MenuBarMetric.allCases, id: \.self) { metric in
          Text(metric.displayName).tag(metric)
        }
      }
      Picker("Default period", selection: $dependencies.settings.defaultReportingPeriod) {
        ForEach(ReportingPeriod.allCases, id: \.self) { period in
          Text(period.displayName).tag(period)
        }
      }
      Picker("Retention", selection: $dependencies.settings.retentionPeriod) {
        ForEach(RetentionPeriod.allCases, id: \.self) { period in
          Text(period.rawValue).tag(period)
        }
      }
      Toggle(
        "Launch at login",
        isOn: Binding(
          get: { dependencies.settings.launchAtLogin },
          set: { enabled in
            do {
              try LaunchAtLoginController.setEnabled(enabled)
              dependencies.settings.launchAtLogin = enabled
            } catch {
              dependencies.diagnosticsText = Redactor().redact(error.localizedDescription)
              dependencies.settings.launchAtLogin = LaunchAtLoginController.isEnabled
            }
            dependencies.saveSettings()
          }
        )
      )
      Section("Collectors") {
        ForEach(CollectorIdentifier.allCases, id: \.self) { collector in
          Toggle(
            collector.displayName,
            isOn: Binding(
              get: { dependencies.settings.enabledCollectors.contains(collector) },
              set: { enabled in
                if enabled {
                  dependencies.settings.enabledCollectors.insert(collector)
                } else {
                  dependencies.settings.enabledCollectors.remove(collector)
                }
                dependencies.saveSettings()
              }
            ))
        }
      }
      Section("Data") {
        Button("Delete all local usage data", role: .destructive) {
          dependencies.deleteAllData()
        }
        Text("Data is stored under ~/Library/Application Support/TokenGlance.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding()
    .frame(width: 440)
    .onChange(of: dependencies.settings) { _, _ in dependencies.saveSettings() }
  }
}
