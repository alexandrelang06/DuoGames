public enum UnlockOrigin: Sendable, Equatable {
    /// Le joueur a touché un jeu verrouillé depuis le hub.
    case lockedGame(GameID)
    /// Proposition après une victoire, sur un moment de joie (DESIGN.md §6.3).
    case afterVictory(GameID)
}

public enum AppScreen: Sendable, Equatable {
    case onboarding(step: Int)
    case hub
    /// « Pose ton téléphone à plat » : guidage avant de lancer la partie.
    case postureGuidance(GameID)
    case tutorial(GameID)
    case playing(GameID)
    case gameOver(GameID, MatchResult)
    case unlock(UnlockOrigin)
    case profile
    case settings
    case leaderboard(GameID?)
}

public enum FlowIntent: Sendable, Equatable {
    case launch
    case advanceOnboarding
    case skipOnboarding
    case selectGame(GameID)
    case postureBecameReady
    case postureBecameUnsuitable
    case dismissTutorial
    case finishGame(MatchResult)
    case rematch
    case backToHub
    case openProfile
    case openSettings
    case openLeaderboard(GameID?)
    case purchaseSucceeded
    case purchaseCancelled
    case restoreSucceeded
}

public struct FlowProgress: Sendable, Hashable {
    public var onboardingCompleted: Bool
    public var tutorialsSeen: Set<GameID>

    public init(onboardingCompleted: Bool = false, tutorialsSeen: Set<GameID> = []) {
        self.onboardingCompleted = onboardingCompleted
        self.tutorialsSeen = tutorialsSeen
    }
}

/// Parcours complet de l'app, modélisé hors de SwiftUI.
///
/// Tout écran intermédiaire est ici : onboarding, hub, guidage de posture, tutoriel,
/// partie, fin de partie, déblocage, espace joueur, réglages, classement. L'interface
/// n'aura plus qu'à rendre `screen` et émettre des intentions.
public struct AppFlow: Sendable {
    public static let onboardingStepCount = 3

    public private(set) var screen: AppScreen
    public private(set) var progress: FlowProgress
    public private(set) var entitlements: Entitlements
    public private(set) var profiles: PlayerProfiles
    public let catalog: Catalog

    /// L'appareil est-il à plat ? Renseigné par `PostureKit` côté app.
    public private(set) var isPostureReady: Bool
    /// Le déblocage n'est proposé qu'une fois par session : on ne harcèle pas.
    public private(set) var unlockPromptedThisSession: Bool
    /// Jeu à lancer une fois l'achat effectué.
    private var pendingGame: GameID?

    public init(
        catalog: Catalog = .default,
        progress: FlowProgress = FlowProgress(),
        entitlements: Entitlements = Entitlements(),
        profiles: PlayerProfiles = PlayerProfiles(),
        isPostureReady: Bool = true
    ) {
        self.catalog = catalog
        self.progress = progress
        self.entitlements = entitlements
        self.profiles = profiles
        self.isPostureReady = isPostureReady
        self.unlockPromptedThisSession = false
        self.screen = progress.onboardingCompleted ? .hub : .onboarding(step: 0)
    }

    /// Remplace les profils joueurs sans changer d'écran (saisie des prénoms, avatars).
    public mutating func updateProfiles(_ profiles: PlayerProfiles) {
        self.profiles = profiles
    }

    public func isUnlocked(_ game: GameID) -> Bool {
        entitlements.isUnlocked(game, in: catalog)
    }

    public var hasLockedGames: Bool {
        GameID.allCases.contains { !isUnlocked($0) }
    }

    // MARK: - Transitions

    public mutating func handle(_ intent: FlowIntent) {
        switch intent {
        case .launch:
            screen = progress.onboardingCompleted ? .hub : .onboarding(step: 0)

        case .advanceOnboarding:
            guard case .onboarding(let step) = screen else { break }
            let next = step + 1
            if next >= Self.onboardingStepCount {
                completeOnboarding()
            } else {
                screen = .onboarding(step: next)
            }

        case .skipOnboarding:
            guard case .onboarding = screen else { break }
            completeOnboarding()

        case .selectGame(let game):
            enter(game)

        case .postureBecameReady:
            isPostureReady = true
            if case .postureGuidance(let game) = screen {
                screen = nextStepAfterPosture(for: game)
            }

        case .postureBecameUnsuitable:
            isPostureReady = false
            // On n'interrompt qu'une partie en cours : ailleurs, le guidage serait intrusif.
            if case .playing(let game) = screen {
                screen = .postureGuidance(game)
            }

        case .dismissTutorial:
            guard case .tutorial(let game) = screen else { break }
            progress.tutorialsSeen.insert(game)
            screen = .playing(game)

        case .finishGame(let result):
            guard case .playing(let game) = screen else { break }
            profiles.record(Duel(game: game, result: result))
            screen = .gameOver(game, result)

        case .rematch:
            guard case .gameOver(let game, _) = screen else { break }
            screen = isPostureReady ? .playing(game) : .postureGuidance(game)

        case .backToHub:
            // Sortie d'une fin de partie : c'est le seul endroit où proposer l'achat.
            if case .gameOver(let game, _) = screen, shouldProposeUnlock() {
                unlockPromptedThisSession = true
                screen = .unlock(.afterVictory(game))
            } else {
                screen = .hub
            }

        case .openProfile:
            screen = .profile

        case .openSettings:
            screen = .settings

        case .openLeaderboard(let game):
            screen = .leaderboard(game)

        case .purchaseSucceeded, .restoreSucceeded:
            // Après l'achat, on revient au hub : le joueur choisit lui-même quel jeu lancer,
            // plutôt que d'être propulsé directement dans celui qu'il avait touché.
            entitlements.grantCollection()
            pendingGame = nil
            screen = .hub

        case .purchaseCancelled:
            pendingGame = nil
            screen = .hub
        }
    }

    // MARK: - Détail

    private mutating func completeOnboarding() {
        progress.onboardingCompleted = true
        screen = .hub
    }

    /// Aiguillage unique vers une partie : verrou, posture, tutoriel, puis jeu.
    private mutating func enter(_ game: GameID) {
        guard isUnlocked(game) else {
            pendingGame = game
            unlockPromptedThisSession = true
            screen = .unlock(.lockedGame(game))
            return
        }
        screen = nextStepAfterPosture(for: game)
    }

    private func nextStepAfterPosture(for game: GameID) -> AppScreen {
        guard isPostureReady else { return .postureGuidance(game) }
        return progress.tutorialsSeen.contains(game) ? .playing(game) : .tutorial(game)
    }

    /// Le déblocage se propose sur un moment de joie, une seule fois, et jamais si tout est acquis.
    private func shouldProposeUnlock() -> Bool {
        hasLockedGames && !unlockPromptedThisSession
    }
}
