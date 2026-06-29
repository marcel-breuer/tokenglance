import ServiceManagement
import SwiftUI
import TokenGlanceCore

struct SettingsView: View {
  @EnvironmentObject private var dependencies: AppDependencies
  private var strings: AppStrings { AppStrings(dependencies.settings.language) }

  var body: some View {
    Form {
      Picker(strings.languageSetting, selection: $dependencies.settings.language) {
        ForEach(AppLanguage.allCases, id: \.self) { language in
          Text(language.localizedName(using: strings)).tag(language)
        }
      }
      Picker(strings.defaultPeriod, selection: $dependencies.settings.defaultReportingPeriod) {
        ForEach(ReportingPeriod.allCases, id: \.self) { period in
          Text(period.localizedName(using: strings)).tag(period)
        }
      }
      Picker(strings.menuBarMetric, selection: $dependencies.settings.menuBarMetric) {
        ForEach(MenuBarMetric.selectableCases, id: \.self) { metric in
          Text(metric.localizedName(using: strings)).tag(metric)
        }
      }
      Picker(strings.retention, selection: $dependencies.settings.retentionPeriod) {
        ForEach(RetentionPeriod.allCases, id: \.self) { period in
          Text(period.localizedName(using: strings)).tag(period)
        }
      }
      Toggle(
        strings.launchAtLogin,
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
      Section(strings.liveUpdates) {
        Toggle(strings.liveRefresh, isOn: $dependencies.settings.liveRefreshEnabled)
        Stepper(
          strings.everySeconds(Int(dependencies.settings.liveRefreshIntervalSeconds)),
          value: $dependencies.settings.liveRefreshIntervalSeconds,
          in: 2...60,
          step: 1
        )
        .disabled(!dependencies.settings.liveRefreshEnabled)
        Text(strings.autoRefreshDescription)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Section(strings.costProfiles) {
        Text(strings.costProfileDescription(dependencies.settings.modelCostProfiles.count))
          .font(.caption)
          .foregroundStyle(.secondary)
        ForEach(dependencies.settings.modelCostProfiles.indices, id: \.self) { index in
          VStack(alignment: .leading, spacing: 6) {
            TextField(
              strings.modelPattern,
              text: $dependencies.settings.modelCostProfiles[index].modelPattern
            )
            HStack {
              TextField(
                strings.inputCost,
                value: $dependencies.settings.modelCostProfiles[index].inputCostPerMillion,
                format: .number.precision(.fractionLength(0...4))
              )
              TextField(
                strings.outputCost,
                value: $dependencies.settings.modelCostProfiles[index].outputCostPerMillion,
                format: .number.precision(.fractionLength(0...4))
              )
              TextField(
                strings.cachedCost,
                value: $dependencies.settings.modelCostProfiles[index].cachedInputCostPerMillion,
                format: .number.precision(.fractionLength(0...4))
              )
              Button {
                dependencies.settings.modelCostProfiles.remove(at: index)
              } label: {
                Image(systemName: "trash")
              }
              .buttonStyle(.borderless)
            }
          }
        }
        Button {
          dependencies.settings.modelCostProfiles.append(
            ModelCostProfile(modelPattern: "gpt", inputCostPerMillion: 0, outputCostPerMillion: 0)
          )
        } label: {
          Label(strings.addCostProfile, systemImage: "plus")
        }
      }
      Section(strings.collectors) {
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
      Section(strings.data) {
        Button(strings.deleteAllLocalUsageData, role: .destructive) {
          dependencies.deleteAllData()
        }
        Text(strings.dataStoredUnder)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding()
    .frame(width: 440)
    .onChange(of: dependencies.settings) { _, _ in dependencies.saveSettings() }
  }
}
