import SwiftUI
import AppFlow
import PostureKit
import Diagnostics

/// Pont entre la machine à états pure (`AppFlow`) et SwiftUI.
@MainActor
@Observable
final class FlowModel {
    private(set) var flow: AppFlow
    let posture: any PostureProviding

    init(posture: any PostureProviding = SimulatedPostureProvider()) {
        self.posture = posture
        var loaded = AppFlow(
            progress: Persistence.loadProgress(),
            entitlements: Persistence.loadEntitlements(),
            profiles: Persistence.loadProfiles(),
            isPostureReady: posture.current.posture != .partiallyFolded
        )
        loaded.handle(.launch)
        self.flow = loaded
        applyDebugLaunchArguments()
    }

    /// `-openGame chess` saute directement dans une partie. Réservé aux builds de développement,
    /// pour piloter le simulateur depuis la ligne de commande.
    private func applyDebugLaunchArguments() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-openTutorial"),
           arguments.indices.contains(index + 1),
           let game = GameID(rawValue: arguments[index + 1]) {
            flow.handle(.skipOnboarding)
            flow.handle(.restoreSucceeded)
            flow.handle(.selectGame(game))   // s'arrête sur le tutoriel, sans le passer
            return
        }
        if arguments.contains("-openSettings") {
            flow.handle(.skipOnboarding)
            flow.handle(.openSettings)
            return
        }
        if arguments.contains("-openUnlock") {
            flow.handle(.skipOnboarding)
            flow.handle(.selectGame(.chess))   // verrouillé par défaut : ouvre l'écran de déblocage
            return
        }
        guard let index = arguments.firstIndex(of: "-openGame"),
              arguments.indices.contains(index + 1),
              let game = GameID(rawValue: arguments[index + 1]) else { return }
        flow.handle(.skipOnboarding)
        flow.handle(.restoreSucceeded)
        flow.handle(.selectGame(game))
        flow.handle(.dismissTutorial)
        #endif
    }

    var screen: AppScreen { flow.screen }

    /// Dernier état de posture déduit de la taille, pour n'émettre un changement qu'au basculement.
    private var lastPostureReady: Bool?

    /// Appelé quand la taille de la fenêtre change (rotation, pliage du Duo, Split View iPad).
    ///
    /// Sans l'API charnière (SDK 26.5), la taille disponible est le meilleur signal : un écran
    /// assez grand pour un plateau à deux joueurs = « à plat, prêt ». S'il rétrécit sous le seuil,
    /// l'app repasse en guidage. Le jour de `DuoPostureProvider`, seule cette source changera.
    func updateAvailableSize(_ size: CGSize) {
        let minSide = min(size.width, size.height)
        // Seuil : de quoi afficher deux demi-plateaux lisibles tête-bêche.
        let ready = minSide >= 360
        guard ready != lastPostureReady else { return }
        lastPostureReady = ready
        flow.handle(ready ? .postureBecameReady : .postureBecameUnsuitable)
    }

    func send(_ intent: FlowIntent) {
        flow.handle(intent)
        Persistence.save(flow)
        DiagnosticsCenter.shared.record(.info, category: "flow", "\(intent) -> \(flow.screen)")
    }

    func isUnlocked(_ game: GameID) -> Bool { flow.isUnlocked(game) }

    /// Renomme un joueur sans changer d'écran : utilisable depuis l'onboarding comme le profil.
    func rename(_ seat: Seat, to name: String) {
        var profiles = flow.profiles
        profiles.rename(seat, to: name)
        flow.updateProfiles(profiles)
        Persistence.saveProfiles(profiles)
    }
}

/// Persistance minimale en `UserDefaults` (PRD §6.1). Rien ne quitte l'appareil.
@MainActor
enum Persistence {
    private static let defaults = UserDefaults.standard

    static func loadProgress() -> FlowProgress {
        FlowProgress(
            onboardingCompleted: defaults.bool(forKey: "progress.onboarding"),
            tutorialsSeen: Set((defaults.stringArray(forKey: "progress.tutorials") ?? []).compactMap(GameID.init))
        )
    }

    static func loadEntitlements() -> Entitlements {
        Entitlements(hasCollection: defaults.bool(forKey: "entitlements.collection"))
    }

    static func loadProfiles() -> PlayerProfiles {
        var profiles = PlayerProfiles()
        if let one = defaults.string(forKey: "profile.one.name") { profiles.rename(.one, to: one) }
        if let two = defaults.string(forKey: "profile.two.name") { profiles.rename(.two, to: two) }
        if let raw = defaults.array(forKey: "profile.history") as? [[String: String]] {
            for entry in raw {
                guard let game = entry["game"].flatMap(GameID.init) else { continue }
                let result: MatchResult = switch entry["result"] {
                case "one": .winner(.one)
                case "two": .winner(.two)
                default: .draw
                }
                profiles.record(Duel(game: game, result: result))
            }
        }
        return profiles
    }

    static func save(_ flow: AppFlow) {
        defaults.set(flow.progress.onboardingCompleted, forKey: "progress.onboarding")
        defaults.set(flow.progress.tutorialsSeen.map(\.rawValue), forKey: "progress.tutorials")
        defaults.set(flow.entitlements.hasCollection, forKey: "entitlements.collection")
        saveProfiles(flow.profiles)
    }

    static func saveProfiles(_ profiles: PlayerProfiles) {
        defaults.set(profiles.profile(.one).name, forKey: "profile.one.name")
        defaults.set(profiles.profile(.two).name, forKey: "profile.two.name")
        let history: [[String: String]] = profiles.history.map { duel in
            let result: String = switch duel.result {
            case .winner(.one): "one"
            case .winner(.two): "two"
            case .draw: "draw"
            }
            return ["game": duel.game.rawValue, "result": result]
        }
        defaults.set(history, forKey: "profile.history")
    }
}
