import SwiftUI
import TokenGlanceCore

struct OnboardingView: View {
  @EnvironmentObject private var dependencies: AppDependencies
  private var strings: AppStrings { AppStrings(dependencies.settings.language) }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("TokenGlance").font(.title.weight(.semibold))
      Text(strings.onboardingPrivacy)
      Text(strings.onboardingCollectors)
      Button(strings.continueButton) { dependencies.completeOnboarding() }
    }
    .padding()
  }
}
