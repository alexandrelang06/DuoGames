import Testing
@testable import BattleshipEngine

@Suite("Placement de la flotte")
struct PlacementTests {

    @Test("Les cinq navires ont les tailles 5/4/3/3/2 du PRD")
    func fleetSizes() {
        let lengths = ShipKind.allCases.map(\.length).sorted(by: >)
        #expect(lengths == [5, 4, 3, 3, 2])
    }

    @Test("Un navire horizontal occupe des cases contiguës vers la droite")
    func horizontalCoordinates() {
        let placement = ShipPlacement(kind: .cruiser, origin: Coordinate(x: 2, y: 4), orientation: .horizontal)
        #expect(placement.coordinates == [
            Coordinate(x: 2, y: 4), Coordinate(x: 3, y: 4), Coordinate(x: 4, y: 4),
        ])
    }

    @Test("Un navire vertical occupe des cases contiguës vers le bas")
    func verticalCoordinates() {
        let placement = ShipPlacement(kind: .destroyer, origin: Coordinate(x: 7, y: 8), orientation: .vertical)
        #expect(placement.coordinates == [Coordinate(x: 7, y: 8), Coordinate(x: 7, y: 9)])
    }

    @Test("Un placement valide est accepté")
    func validPlacement() throws {
        var board = Board()
        let placement = ShipPlacement(kind: .carrier, origin: Coordinate(x: 0, y: 0), orientation: .horizontal)
        #expect(board.validate(placement) == nil)
        try board.place(placement)
        #expect(board.placements.count == 1)
    }

    @Test("Un navire qui dépasse par la droite est refusé")
    func rejectsOutOfBoundsHorizontally() {
        var board = Board()
        // Porte-avions de 5 cases posé en x=6 : occupe 6,7,8,9,10 -> 10 est hors grille.
        let placement = ShipPlacement(kind: .carrier, origin: Coordinate(x: 6, y: 0), orientation: .horizontal)
        #expect(board.validate(placement) == .outOfBounds(.carrier))
        #expect(throws: PlacementError.outOfBounds(.carrier)) { try board.place(placement) }
    }

    @Test("Un navire qui dépasse par le bas est refusé")
    func rejectsOutOfBoundsVertically() {
        var board = Board()
        let placement = ShipPlacement(kind: .battleship, origin: Coordinate(x: 3, y: 7), orientation: .vertical)
        #expect(board.validate(placement) == .outOfBounds(.battleship))
    }

    @Test("Une coordonnée négative est refusée")
    func rejectsNegativeCoordinate() {
        var board = Board()
        let placement = ShipPlacement(kind: .destroyer, origin: Coordinate(x: -1, y: 0), orientation: .horizontal)
        #expect(board.validate(placement) == .outOfBounds(.destroyer))
    }

    @Test("Deux navires ne peuvent pas se chevaucher")
    func rejectsOverlap() throws {
        var board = Board()
        try board.place(ShipPlacement(kind: .carrier, origin: Coordinate(x: 0, y: 0), orientation: .horizontal))
        let crossing = ShipPlacement(kind: .cruiser, origin: Coordinate(x: 2, y: 0), orientation: .vertical)
        #expect(board.validate(crossing) == .overlaps(.cruiser, with: .carrier))
    }

    @Test("Deux navires côte à côte sans chevauchement sont acceptés")
    func allowsAdjacentShips() throws {
        var board = Board()
        try board.place(ShipPlacement(kind: .carrier, origin: Coordinate(x: 0, y: 0), orientation: .horizontal))
        let adjacent = ShipPlacement(kind: .cruiser, origin: Coordinate(x: 0, y: 1), orientation: .horizontal)
        #expect(board.validate(adjacent) == nil)
        try board.place(adjacent)
        #expect(board.placements.count == 2)
    }

    @Test("Le même type de navire ne peut pas être posé deux fois")
    func rejectsDuplicateKind() throws {
        var board = Board()
        try board.place(ShipPlacement(kind: .destroyer, origin: Coordinate(x: 0, y: 0), orientation: .horizontal))
        let duplicate = ShipPlacement(kind: .destroyer, origin: Coordinate(x: 5, y: 5), orientation: .horizontal)
        #expect(board.validate(duplicate) == .duplicateKind(.destroyer))
    }

    @Test("Un navire retiré libère ses cases et peut être reposé")
    func removeFreesCells() throws {
        var board = Board()
        let original = ShipPlacement(kind: .cruiser, origin: Coordinate(x: 4, y: 4), orientation: .horizontal)
        try board.place(original)
        #expect(board.remove(.cruiser) == true)
        #expect(board.placements.isEmpty)
        #expect(board.validate(original) == nil)
        #expect(board.remove(.cruiser) == false)
    }

    @Test("La flotte n'est complète qu'avec les cinq navires")
    func fleetCompletion() throws {
        var board = Board()
        #expect(board.isFleetComplete == false)
        #expect(Set(board.missingShips) == Set(ShipKind.allCases))

        for (index, kind) in ShipKind.allCases.enumerated() {
            try board.place(ShipPlacement(kind: kind, origin: Coordinate(x: 0, y: index), orientation: .horizontal))
        }
        #expect(board.isFleetComplete)
        #expect(board.missingShips.isEmpty)
    }

    @Test("La notation de grille est celle du jeu")
    func coordinateNotation() {
        #expect(Coordinate(x: 0, y: 0).description == "A1")
        #expect(Coordinate(x: 9, y: 9).description == "J10")
    }
}
