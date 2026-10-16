public enum GameID: String, Sendable, Hashable, CaseIterable {
    case airHockey
    case chess
    case draughts
    case tron
    case mill

    public var titleKey: String { "game.\(rawValue).title" }
    public var pitchKey: String { "game.\(rawValue).pitch" }
    public var tutorialKey: String { "game.\(rawValue).tutorial" }

    /// Un jeu temps réel se joue à quatre mains simultanément ; un jeu au tour par tour non.
    public var isRealTime: Bool {
        switch self {
        case .airHockey, .tron: true
        case .chess, .draughts, .mill: false
        }
    }
}

/// Ce qui est offert et ce qui se débloque.
///
/// Modèle retenu le 10 septembre 2026 : téléchargement gratuit, un jeu jouable
/// intégralement, le reste débloqué par un achat unique non consommable.
public struct Catalog: Sendable, Hashable {
    public let freeGames: Set<GameID>
    public let unlockProductID: String

    public static let `default` = Catalog(
        freeGames: [.airHockey],
        unlockProductID: "com.duogames.unlock.collection"
    )

    public init(freeGames: Set<GameID>, unlockProductID: String) {
        self.freeGames = freeGames
        self.unlockProductID = unlockProductID
    }

    public var paidGames: [GameID] {
        GameID.allCases.filter { !freeGames.contains($0) }
    }
}

public struct Entitlements: Sendable, Hashable {
    public private(set) var hasCollection: Bool

    public init(hasCollection: Bool = false) {
        self.hasCollection = hasCollection
    }

    public func isUnlocked(_ game: GameID, in catalog: Catalog) -> Bool {
        catalog.freeGames.contains(game) || hasCollection
    }

    public mutating func grantCollection() { hasCollection = true }
    public mutating func revokeCollection() { hasCollection = false }
}
