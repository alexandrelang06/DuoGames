import GameKit
import AppFlow
import Diagnostics

/// Implémentation Game Center de `LeaderboardReporting`. Seul fichier de l'app qui importe GameKit.
///
/// Décision du 10 septembre 2026 : classements natifs Apple, zéro backend, zéro compte à créer.
/// L'authentification est déclenchée une fois, silencieusement ; si Apple veut présenter une
/// feuille de connexion, elle est montrée, sinon on n'insiste pas. Un refus n'empêche jamais de jouer.
@MainActor
final class GameCenterLeaderboard: LeaderboardReporting {
    static let shared = GameCenterLeaderboard()

    private(set) var isAuthenticated = false

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                guard let self else { return }
                if let viewController {
                    Self.present(viewController)
                    return
                }
                if let error {
                    DiagnosticsCenter.shared.record(.warning, category: "gamecenter", "Auth : \(error.localizedDescription)")
                }
                self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                DiagnosticsCenter.shared.record(.info, category: "gamecenter",
                                                self.isAuthenticated ? "Connecté" : "Non connecté")
            }
        }
    }

    nonisolated func isAvailable() async -> Bool {
        await MainActor.run { GKLocalPlayer.local.isAuthenticated }
    }

    nonisolated func submit(score: Int, to leaderboard: LeaderboardID) async throws {
        guard await isAvailable() else { return }
        try await GKLeaderboard.submitScore(
            score, context: 0, player: GKLocalPlayer.local,
            leaderboardIDs: [leaderboard.rawValue]
        )
    }

    /// Affiche le tableau Game Center natif via le point d'accès système (iOS 26+).
    func showLeaderboards() {
        GKAccessPoint.shared.trigger(state: .leaderboards) { }
    }

    private static func present(_ controller: UIViewController) {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let root = scene.keyWindow?.rootViewController else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        top.present(controller, animated: true)
    }
}

