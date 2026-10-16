/// Coordonnée sur la grille. Origine en haut à gauche, `x` vers la droite, `y` vers le bas.
public struct Coordinate: Hashable, Sendable, CustomStringConvertible {
    public let x: Int
    public let y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    /// Notation usuelle du jeu : « A1 », « J10 ».
    public var description: String {
        guard (0..<26).contains(x) else { return "(\(x),\(y))" }
        let column = String(UnicodeScalar(UInt8(65 + x)))
        return "\(column)\(y + 1)"
    }
}

public enum Orientation: Sendable, Hashable, CaseIterable {
    case horizontal
    case vertical

    public var toggled: Orientation { self == .horizontal ? .vertical : .horizontal }
}

/// Les cinq navires classiques, tailles 5/4/3/3/2 (PRD §5.1).
public enum ShipKind: String, Sendable, Hashable, CaseIterable {
    case carrier
    case battleship
    case cruiser
    case submarine
    case destroyer

    public var length: Int {
        switch self {
        case .carrier: 5
        case .battleship: 4
        case .cruiser: 3
        case .submarine: 3
        case .destroyer: 2
        }
    }

    /// Clé de localisation. Aucun texte en dur (PRD §10.5).
    public var localizationKey: String { "ship.\(rawValue)" }
}
