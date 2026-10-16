/// Classement en ligne.
///
/// Décision du 10 septembre 2026 : **Game Center** et rien d'autre. Leaderboards natifs
/// Apple, aucun backend à écrire ni à héberger, aucun compte à créer — l'identifiant Apple
/// du joueur suffit. Ce protocole isole GameKit du code métier, exactement comme
/// `PostureProviding` isole les APIs pliables.
///
/// Conséquence à assumer : des données quittent l'appareil. La mention « Rien ne quitte
/// l'appareil » disparaît donc de l'espace joueur au profit d'une formulation exacte.
public protocol LeaderboardReporting: Sendable {
    func submit(score: Int, to leaderboard: LeaderboardID) async throws
    func isAvailable() async -> Bool
}

public struct LeaderboardID: Sendable, Hashable {
    public let rawValue: String

    public init(_ rawValue: String) { self.rawValue = rawValue }

    public static func wins(_ game: GameID) -> LeaderboardID {
        LeaderboardID("com.duogames.leaderboard.\(game.rawValue).wins")
    }
}

/// Implémentation locale, utilisable hors ligne et en test : elle retient ce qui aurait
/// été envoyé, sans jamais rien émettre.
public actor LocalLeaderboard: LeaderboardReporting {
    public private(set) var submissions: [LeaderboardID: [Int]] = [:]
    private let available: Bool

    public init(available: Bool = true) {
        self.available = available
    }

    public func submit(score: Int, to leaderboard: LeaderboardID) async throws {
        submissions[leaderboard, default: []].append(score)
    }

    public func isAvailable() async -> Bool { available }

    public func scores(for leaderboard: LeaderboardID) -> [Int] {
        submissions[leaderboard] ?? []
    }
}
