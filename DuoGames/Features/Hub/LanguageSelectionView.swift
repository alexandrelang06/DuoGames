import SwiftUI

/// Premier écran au tout premier lancement : choisir la langue avant l'onboarding.
///
/// Par défaut l'app suit déjà la langue de l'appareil ; cet écran laisse la changer d'emblée
/// parmi les cinq langues prévues. Une fois choisie, on ne le revoit plus (modifiable dans les
/// réglages). Le drapeau du pays sert de repère visuel.
struct LanguageSelectionView: View {
    @AppStorage("settings.language") private var languageRaw = AppLanguage.system.rawValue
    @AppStorage("settings.languagePicked") private var picked = false

    /// Les cinq langues proposées, sans l'option « système » : ici on choisit explicitement.
    private let options: [AppLanguage] = [.en, .fr, .es, .it, .de]

    var body: some View {
        ScrollView {
          VStack(spacing: Theme.Space.xl) {
            Image(systemName: "globe")
                .font(.system(size: 64, weight: .thin))
                .foregroundStyle(Theme.Umbrella.ink)
                .accessibilityHidden(true)
                .padding(.top, Theme.Space.xxl)
            Text("onboarding.language.title")
                .font(Theme.Typo.display(32))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: Theme.Space.s) {
                ForEach(options) { language in
                    Button {
                        languageRaw = language.rawValue
                        picked = true
                    } label: {
                        HStack(spacing: Theme.Space.m) {
                            Text(language.flag).font(.title2)
                            Text(language.nativeName)
                                .font(.body.weight(.medium))
                            Spacer()
                        }
                        .padding(Theme.Space.m)
                        .frame(maxWidth: .infinity)
                        .background(Theme.Umbrella.ink.opacity(0.04), in: RoundedRectangle(cornerRadius: Theme.Radius.control))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.Umbrella.ink)
                    // Chaque option est présentée dans sa propre langue.
                    .environment(\.locale, Locale(identifier: language.rawValue))
                }
            }
          }
          .padding(Theme.Space.l)
          .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Umbrella.paper)
    }
}
