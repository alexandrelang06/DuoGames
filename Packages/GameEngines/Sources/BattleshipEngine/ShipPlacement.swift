/// Position d'un navire sur la grille : un type, une origine, une orientation.
public struct ShipPlacement: Hashable, Sendable {
    public let kind: ShipKind
    public let origin: Coordinate
    public let orientation: Orientation

    public init(kind: ShipKind, origin: Coordinate, orientation: Orientation) {
        self.kind = kind
        self.origin = origin
        self.orientation = orientation
    }

    /// Toutes les cases occupées, de l'origine vers la droite ou vers le bas.
    public var coordinates: [Coordinate] {
        (0..<kind.length).map { offset in
            switch orientation {
            case .horizontal: Coordinate(x: origin.x + offset, y: origin.y)
            case .vertical: Coordinate(x: origin.x, y: origin.y + offset)
            }
        }
    }

    public func occupies(_ coordinate: Coordinate) -> Bool {
        coordinates.contains(coordinate)
    }
}

public enum PlacementError: Error, Equatable, Sendable {
    /// Le navire dépasse de la grille.
    case outOfBounds(ShipKind)
    /// Le navire chevauche un navire déjà posé.
    case overlaps(ShipKind, with: ShipKind)
    /// Ce type de navire est déjà posé. La flotte en compte exactement un de chaque.
    case duplicateKind(ShipKind)
    /// La flotte n'est pas complète, on ne peut pas valider.
    case fleetIncomplete(missing: [ShipKind])
}
