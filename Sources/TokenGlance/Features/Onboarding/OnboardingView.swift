import SwiftUI
import TokenGlanceCore

struct OnboardingView: View {
  @EnvironmentObject private var dependencies: AppDependencies

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("TokenGlance").font(.title.weight(.semibold))
      Text(
        "Usage metadata is processed locally. TokenGlance does not upload usage data, prompts, responses, source code, or credentials."
      )
      Text(
        "Collectors read only verified token metadata and can be disabled individually in Settings."
      )
      Button("Continue") { dependencies.completeOnboarding() }
    }
    .padding()
  }
}
