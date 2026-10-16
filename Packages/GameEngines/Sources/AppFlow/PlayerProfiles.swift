import Foundation

/// Les deux places autour de l'appareil. Aucun compte, aucun réseau : tout est local.
public enum Seat: String, Sendable, Hashable, CaseIterable {
    case one
    case two

    public var other: Seat { self == .one ? .two : .one }
    public var localizationKey: String { "seat.\(rawValue)" }
}

public enum MatchResult: Sendable, Hashable {
    case winner(Seat)
    case draw

    public var winner: Seat? {
        if case .winner(let seat) = self { return seat }
        return nil
    }
}

public struct Duel: Sendable, Hashable {
    public let game: GameID
    public let result: MatchResult

    public init(game: GameID, result: MatchResult) {
        self.game = game
        self.result = result
    }
}

public struct PlayerProfile: Sendable, Hashable {
    public var name: String
    public var avatar: String

    public init(name: String, avatar: String) {
        self.name = name
        self.avatar = avatar
    }
}

/// Espace joueur : prénoms, avatars, historique. Rien ne quitte l'appareil.
public struct PlayerProfiles: Sendable, Hashable {
    public private(set) var profiles: [Seat: PlayerProfile]
    public private(set) var history: [Duel]
    /// Historique borné : inutile de laisser grossir un journal sur l'appareil du joueur.
    public let historyLimit: Int

    public init(historyLimit: Int = 20) {
        self.historyLimit = historyLimit
        self.profiles = [
            .one: PlayerProfile(name: "", avatar: "circle"),
            .two: PlayerProfile(name: "", avatar: "square"),
        ]
        self.history = []
    }

    public func profile(_ seat: Seat) -> PlayerProfile { profiles[seat]! }

    public mutating func rename(_ seat: Seat, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        profiles[seat]?.name = String(trimmed.prefix(16))
    }

    public mutating func setAvatar(_ seat: Seat, to avatar: String) {
        profiles[seat]?.avatar = avatar
    }

    public mutating func record(_ duel: Duel) {
        history.append(duel)
        if history.count > historyLimit {
            history.removeFirst(history.count - historyLimit)
        }
    }

    public func wins(_ seat: Seat) -> Int {
        history.filter { $0.result.winner == seat }.count
    }

    public func draws() -> Int {
        history.filter { $0.result == .draw }.count
    }

    public func wins(_ seat: Seat, at game: GameID) -> Int {
        history.filter { $0.game == game && $0.result.winner == seat }.count
    }

    /// Le plus récent d'abord.
    public var recentDuels: [Duel] { history.reversed() }
}
