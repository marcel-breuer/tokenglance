import SwiftUI
import TokenGlanceCore

struct OnboardingView: View {
  @EnvironmentObject private var dependencies: AppDependencies
  private var strings: AppStrings { AppStrings(dependencies.settings.language) }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 10) {
        Image(systemName: "chart.bar.xaxis")
          .font(.title3.weight(.medium))
          .foregroundStyle(.tint)
        Text("TokenGlance").font(.title2.weight(.semibold))
      }
      Text(strings.onboardingPrivacy).foregroundStyle(.secondary)
      Text(strings.onboardingCollectors).foregroundStyle(.secondary)
      Button(strings.continueButton) { dependencies.completeOnboarding() }
        .keyboardShortcut(.defaultAction)
    }
    .padding(20)
    .glassSurface(cornerRadius: 16)
    .padding(16)
  }
}
