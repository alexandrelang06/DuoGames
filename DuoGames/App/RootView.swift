import SwiftUI
import AppFlow

/// Rend l'écran courant de `AppFlow`. Aucune logique de navigation ici : tout est dans la machine à états.
struct RootView: View {
    @Environment(FlowModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("settings.appearance") private var appearanceRaw = Appearance.system.rawValue
    private var appearance: Appearance { Appearance(rawValue: appearanceRaw) ?? .system }
    @AppStorage("settings.language") private var languageRaw = AppLanguage.system.rawValue
    private var language: AppLanguage { AppLanguage(rawValue: languageRaw) ?? .system }
    @AppStorage("settings.languagePicked") private var languagePicked = false
    @AppStorage("onboarding.namesEntered") private var namesEntered = false
    @State private var showSplash = true

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Theme.Umbrella.paper.ignoresSafeArea()
                firstRunOrContent.transition(.opacity)
            }
            // L'app se redimensionne avec la fenêtre ; ce changement met à jour la posture.
            .onChange(of: proxy.size) { _, newSize in
                model.updateAvailableSize(newSize)
            }
            .onAppear { model.updateAvailableSize(proxy.size) }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: model.screen)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: languagePicked)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: namesEntered)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: showSplash)
        .preferredColorScheme(appearance.colorScheme)
        .environment(\.locale, language.locale ?? Locale.autoupdatingCurrent)
    }

    /// Séquence de premier lancement : la langue d'abord (première question posée), puis le splash,
    /// puis les prénoms, puis l'app. Le splash n'apparaît qu'une fois la langue choisie, donc son
    /// minuteur ne démarre qu'à ce moment-là.
    @ViewBuilder
    private var firstRunOrContent: some View {
        if !languagePicked {
            LanguageSelectionView()
        } else if showSplash {
            SplashView()
                .task {
                    try? await Task.sleep(for: .seconds(1.6))
                    showSplash = false
                }
        } else if !namesEntered {
            PlayerNamesView()
        } else {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.screen {
        case .onboarding(let step):
            OnboardingView(step: step)
        case .hub:
            HubView()
        case .postureGuidance(let game):
            PostureGuidanceView(game: game)
        case .tutorial(let game):
            TutorialView(game: game)
        case .playing(let game):
            GameHostView(game: game)
        case .gameOver(let game, let result):
            GameOverView(game: game, result: result)
        case .unlock(let origin):
            UnlockView(origin: origin)
        case .profile:
            ProfileView()
        case .settings:
            SettingsView()
        case .leaderboard(let game):
            LeaderboardView(game: game)
        }
    }
}

/// Aiguillage vers la vue de jeu. Les jeux non encore habillés affichent un chantier honnête.
struct GameHostView: View {
    let game: GameID

    var body: some View {
        switch game {
        case .chess: ChessView()
        case .draughts: DraughtsView()
        case .mill: MillView()
        case .tron: TronView()
        case .airHockey: AirHockeyView()
        }
    }
}
