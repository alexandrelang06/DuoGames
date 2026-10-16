import SwiftUI
import AppFlow

/// Trois écrans, passables à tout moment. Il ne raconte pas l'app : il fait poser le téléphone.
struct OnboardingView: View {
    @Environment(FlowModel.self) private var model
    let step: Int

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            HStack {
                Spacer()
                Button("onboarding.skip") { model.send(.skipOnboarding) }
                    .foregroundStyle(Theme.Umbrella.inkSecondary)
            }

            // Le centre défile si le texte devient trop grand (Dynamic Type), sans masquer les
            // boutons ni les points de progression, qui restent épinglés.
            ScrollView {
                VStack(spacing: Theme.Space.l) {
                    OnboardingAnimation(step: step)
                    VStack(spacing: Theme.Space.s) {
                        Text(titleKey)
                            .font(Theme.Typo.display(34))
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                        Text(subtitleKey)
                            .font(.body)
                            .foregroundStyle(Theme.Umbrella.inkSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Space.xl)
            }
            .scrollBounceBehavior(.basedOnSize)

            HStack(spacing: Theme.Space.s) {
                ForEach(0..<AppFlow.onboardingStepCount, id: \.self) { index in
                    Capsule()
                        .fill(index == step ? Theme.Umbrella.ink : Theme.Umbrella.rule)
                        .frame(width: index == step ? 24 : 8, height: 8)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("onboarding.progress \(step + 1) \(AppFlow.onboardingStepCount)"))

            Button(step == AppFlow.onboardingStepCount - 1 ? "guidance.ready" : "onboarding.next") {
                model.send(.advanceOnboarding)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(Theme.Space.l)
        .foregroundStyle(Theme.Umbrella.ink)
    }

    // Construire la clé en String d'abord : une interpolation directe dans LocalizedStringKey
    // serait traitée comme un argument de format, et la clé ne serait jamais résolue.
    private var titleKey: LocalizedStringKey { LocalizedStringKey(String("onboarding.step\(step + 1).title")) }
    private var subtitleKey: LocalizedStringKey { LocalizedStringKey(String("onboarding.step\(step + 1).subtitle")) }

}
