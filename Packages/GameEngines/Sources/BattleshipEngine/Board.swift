/// Grille d'un joueur : sa flotte et les tirs reçus.
///
/// Type valeur, sans dépendance UI, testable isolément (PRD §6.3).
public struct Board: Sendable, Equatable {
    public static let defaultSize = 10

    public let size: Int
    public private(set) var placements: [ShipPlacement]
    public private(set) var incomingShots: Set<Coordinate>

    public init(size: Int = Board.defaultSize) {
        self.size = size
        self.placements = []
        self.incomingShots = []
    }

    // MARK: - Phase de placement

    public func contains(_ coordinate: Coordinate) -> Bool {
        (0..<size).contains(coordinate.x) && (0..<size).contains(coordinate.y)
    }

    /// Valide un placement sans l'appliquer. Utile pour le retour visuel pendant le drag and drop.
    public func validate(_ placement: ShipPlacement) -> PlacementError? {
        if placements.contains(where: { $0.kind == placement.kind }) {
            return .duplicateKind(placement.kind)
        }
        guard placement.coordinates.allSatisfy(contains) else {
            return .outOfBounds(placement.kind)
        }
        for existing in placements {
            let existingCells = Set(existing.coordinates)
            if placement.coordinates.contains(where: existingCells.contains) {
                return .overlaps(placement.kind, with: existing.kind)
            }
        }
        return nil
    }

    @discardableResult
    public mutating func place(_ placement: ShipPlacement) throws -> ShipPlacement {
        if let error = validate(placement) { throw error }
        placements.append(placement)
        return placement
    }

    /// Retire un navire déjà posé, pour permettre de le repositionner.
    @discardableResult
    public mutating func remove(_ kind: ShipKind) -> Bool {
        guard let index = placements.firstIndex(where: { $0.kind == kind }) else { return false }
        placements.remove(at: index)
        return true
    }

    public var missingShips: [ShipKind] {
        let placed = Set(placements.map(\.kind))
        return ShipKind.allCases.filter { !placed.contains($0) }
    }

    public var isFleetComplete: Bool { missingShips.isEmpty }

    // MARK: - Phase de tir

    public func ship(at coordinate: Coordinate) -> ShipPlacement? {
        placements.first { $0.occupies(coordinate) }
    }

    public func isSunk(_ kind: ShipKind) -> Bool {
        guard let placement = placements.first(where: { $0.kind == kind }) else { return false }
        return placement.coordinates.allSatisfy(incomingShots.contains)
    }

    /// Toute la flotte est coulée : condition de défaite.
    public var isFleetDestroyed: Bool {
        isFleetComplete && ShipKind.allCases.allSatisfy(isSunk)
    }

    /// Applique un tir et renvoie son résultat.
    ///
    /// Un tir sur une case déjà visée ne consomme pas le tour : c'est au moteur de partie
    /// d'interpréter `.alreadyShot` sans changer de joueur.
    public mutating func receiveShot(at coordinate: Coordinate) -> ShotOutcome {
        guard contains(coordinate) else { return .invalid }
        guard !incomingShots.contains(coordinate) else { return .alreadyShot }

        incomingShots.insert(coordinate)

        guard let placement = ship(at: coordinate) else { return .miss }
        return isSunk(placement.kind) ? .sunk(placement.kind) : .hit(placement.kind)
    }
}

public enum ShotOutcome: Equatable, Sendable {
    case miss
    case hit(ShipKind)
    case sunk(ShipKind)
    /// Case déjà visée. Le tour n'est pas consommé.
    case alreadyShot
    /// Hors grille. Le tour n'est pas consommé.
    case invalid

    public var didConsumeTurn: Bool {
        switch self {
        case .miss, .hit, .sunk: true
        case .alreadyShot, .invalid: false
        }
    }

    /// Clé d'événement pour Core/Audio et Core/Haptics (PRD §8.6).
    public var eventKey: String {
        switch self {
        case .miss: "battleship.miss"
        case .hit: "battleship.hit"
        case .sunk: "battleship.sunk"
        case .alreadyShot, .invalid: "battleship.rejected"
        }
    }
}
