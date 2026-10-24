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
          in: AppSettings
            .minimumLiveRefreshIntervalSeconds...AppSettings.maximumLiveRefreshIntervalSeconds,
          step: 15
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
        Text(strings.pricePresetNote)
          .font(.caption)
          .foregroundStyle(.secondary)
        ForEach(dependencies.settings.modelCostProfiles.indices, id: \.self) { index in
          VStack(alignment: .leading, spacing: 6) {
            TextField(
              strings.modelPattern,
              text: pricePatternBinding(at: index)
            )
            Grid(horizontalSpacing: 8, verticalSpacing: 6) {
              GridRow {
                TextField(
                  strings.inputCost,
                  value: priceBinding(at: index, keyPath: \.inputCostPerMillion),
                  format: .number.precision(.fractionLength(0...4))
                )
                TextField(
                  strings.outputCost,
                  value: priceBinding(at: index, keyPath: \.outputCostPerMillion),
                  format: .number.precision(.fractionLength(0...4))
                )
              }
              GridRow {
                TextField(
                  strings.cachedCost,
                  value: priceBinding(at: index, keyPath: \.cachedInputCostPerMillion),
                  format: .number.precision(.fractionLength(0...4))
                )
                TextField(
                  strings.cacheWriteCost,
                  value: cacheCreationBinding(at: index),
                  format: .number.precision(.fractionLength(0...4))
                )
              }
            }
            HStack {
              Button {
                dependencies.settings.modelCostProfiles.remove(at: index)
              } label: {
                Image(systemName: "trash")
              }
              .buttonStyle(.borderless)
            }
            if let source = dependencies.settings.modelCostProfiles[index].sourceURL,
              let url = URL(string: source),
              let date = dependencies.settings.modelCostProfiles[index].checkedOn
            {
              let label = dependencies.settings.modelCostProfiles[index].hasUserOverride
                ? strings.overriddenPriceSourceLabel(date)
                : strings.priceSourceLabel(date)
              Link(label, destination: url)
                .font(.caption)
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
        Button {
          dependencies.settings.modelCostProfiles = ModelCostCatalog.updating(
            dependencies.settings.modelCostProfiles)
        } label: {
          Label(strings.addPricePresets, systemImage: "tag")
        }
      }
      Section(strings.usageBudgets) {
        Toggle(strings.budgetAlerts, isOn: $dependencies.settings.budgetAlertsEnabled)
        Text(strings.budgetAlertHelp)
          .font(.caption)
          .foregroundStyle(.secondary)
        ForEach(dependencies.settings.usageBudgets.indices, id: \.self) { index in
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              TextField(strings.budgetName, text: $dependencies.settings.usageBudgets[index].name)
              Toggle("", isOn: $dependencies.settings.usageBudgets[index].isEnabled)
                .labelsHidden()
              Button {
                dependencies.settings.usageBudgets.remove(at: index)
              } label: {
                Image(systemName: "trash")
              }
              .buttonStyle(.borderless)
            }
            TextField(
              strings.budgetLimit,
              value: $dependencies.settings.usageBudgets[index].limit,
              format: .number.precision(.fractionLength(0...2)))
            Picker(strings.budgetPeriod, selection: $dependencies.settings.usageBudgets[index].period) {
              Text(strings.dailyBudget).tag(UsageBudgetPeriod.day)
              Text(strings.weeklyBudget).tag(UsageBudgetPeriod.week)
              Text(strings.monthlyBudget).tag(UsageBudgetPeriod.month)
            }
            Picker(strings.budgetMetric, selection: $dependencies.settings.usageBudgets[index].metric) {
              Text(strings.tokenBudget).tag(UsageBudgetMetric.tokens)
              Text(strings.costBudget).tag(UsageBudgetMetric.estimatedCost)
            }
            Picker(strings.budgetAlertMode, selection: $dependencies.settings.usageBudgets[index].alertMode) {
              Text(strings.actualBudgetAlert).tag(UsageBudgetAlertMode.actual)
              Text(strings.forecastBudgetAlert).tag(UsageBudgetAlertMode.forecast)
              Text(strings.eitherBudgetAlert).tag(UsageBudgetAlertMode.either)
            }
            HStack {
              ForEach([50, 80, 100], id: \.self) { threshold in
                Toggle(
                  "\(threshold)%",
                  isOn: budgetThresholdBinding(index: index, threshold: threshold))
              }
            }
          }
          .disabled(!dependencies.settings.budgetAlertsEnabled)
        }
        Button {
          dependencies.settings.usageBudgets.append(UsageBudget())
        } label: {
          Label(strings.addBudget, systemImage: "plus")
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

  private func budgetThresholdBinding(index: Int, threshold: Int) -> Binding<Bool> {
    Binding(
      get: { dependencies.settings.usageBudgets[index].alertThresholds.contains(threshold) },
      set: { enabled in
        var thresholds = dependencies.settings.usageBudgets[index].alertThresholds
        if enabled {
          thresholds.append(threshold)
        } else {
          thresholds.removeAll { $0 == threshold }
        }
        dependencies.settings.usageBudgets[index].alertThresholds = thresholds.sorted()
      })
  }

  private func priceBinding(
    at index: Int, keyPath: WritableKeyPath<ModelCostProfile, Double>
  ) -> Binding<Double> {
    Binding(
      get: { dependencies.settings.modelCostProfiles[index][keyPath: keyPath] },
      set: { value in
        dependencies.settings.modelCostProfiles[index][keyPath: keyPath] = value
        dependencies.settings.modelCostProfiles[index].hasUserOverride = true
      })
  }

  private func pricePatternBinding(at index: Int) -> Binding<String> {
    Binding(
      get: { dependencies.settings.modelCostProfiles[index].modelPattern },
      set: { value in
        dependencies.settings.modelCostProfiles[index].modelPattern = value
        dependencies.settings.modelCostProfiles[index].hasUserOverride = true
      })
  }

  private func cacheCreationBinding(at index: Int) -> Binding<Double> {
    Binding(
      get: { dependencies.settings.modelCostProfiles[index].cacheCreationCostPerMillion ?? 0 },
      set: { value in
        dependencies.settings.modelCostProfiles[index].cacheCreationCostPerMillion = value
        dependencies.settings.modelCostProfiles[index].hasUserOverride = true
      })
  }
}
