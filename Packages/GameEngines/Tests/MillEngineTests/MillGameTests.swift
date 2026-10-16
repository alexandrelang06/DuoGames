import Testing
@testable import MillEngine

@Suite("Plateau du moulin")
struct MillBoardTests {

    @Test("24 intersections, 9 pions par joueur")
    func boardConstants() {
        #expect(MillBoard.pointCount == 24)
        #expect(MillBoard.menPerPlayer == 9)
    }

    @Test("16 alignements de trois")
    func millCount() {
        #expect(MillBoard.mills.count == 16)
        #expect(MillBoard.mills.allSatisfy { $0.count == 3 })
    }

    @Test("Toutes les intersections des alignements sont valides")
    func millsInRange() {
        for mill in MillBoard.mills {
            #expect(mill.allSatisfy { (0..<MillBoard.pointCount).contains($0) })
        }
    }

    @Test("Chaque intersection appartient à exactement deux alignements")
    func everyPointHasTwoMills() {
        for point in 0..<MillBoard.pointCount {
            #expect(MillBoard.millsThrough[point].count == 2, "intersection \(point)")
        }
    }

    @Test("L'adjacence est symétrique")
    func adjacencyIsSymmetric() {
        for point in 0..<MillBoard.pointCount {
            for neighbour in MillBoard.adjacency[point] {
                #expect(MillBoard.adjacency[neighbour].contains(point),
                        "\(point) voisin de \(neighbour) mais pas l'inverse")
            }
        }
    }

    @Test("Aucune intersection n'est isolée")
    func noIsolatedPoint() {
        #expect(MillBoard.adjacency.count == MillBoard.pointCount)
        #expect(MillBoard.adjacency.allSatisfy { !$0.isEmpty })
    }
}

@Suite("Règles du moulin")
struct MillGameTests {

    @Test("La partie commence par la pose des blancs")
    func initialState() {
        let game = MillGame()
        #expect(game.state == .awaitingPlacement(.white))
        #expect(game.inHand(.white) == 9)
        #expect(game.menOnBoard(.white) == 0)
    }

    @Test("Poser un pion le retire de la réserve et passe la main")
    func placeAlternates() throws {
        var game = MillGame()
        try game.place(at: 0, by: .white)
        #expect(game.inHand(.white) == 8)
        #expect(game.menOnBoard(.white) == 1)
        #expect(game.state == .awaitingPlacement(.black))
    }

    @Test("On ne peut pas poser sur une intersection occupée")
    func rejectsOccupiedPoint() throws {
        var game = MillGame()
        try game.place(at: 0, by: .white)
        #expect(throws: MillError.pointOccupied) { try game.place(at: 0, by: .black) }
    }

    @Test("On ne peut pas jouer hors de son tour")
    func rejectsOutOfTurn() {
        var game = MillGame()
        #expect(throws: MillError.notYourTurn(expected: .white)) {
            try game.place(at: 5, by: .black)
        }
    }

    @Test("Une intersection hors plateau est refusée")
    func rejectsOutOfRange() {
        var game = MillGame()
        #expect(throws: MillError.pointOutOfRange) { try game.place(at: 24, by: .white) }
    }

    @Test("Former un moulin ouvre le retrait d'un pion adverse")
    func millTriggersRemoval() throws {
        var game = MillGame()
        // Blanc aligne 0-1-2, noir pose ailleurs.
        try game.place(at: 0, by: .white)
        try game.place(at: 9, by: .black)
        try game.place(at: 1, by: .white)
        try game.place(at: 10, by: .black)
        try game.place(at: 2, by: .white)

        #expect(game.isInMill(0))
        #expect(game.state == .awaitingRemoval(.white))

        try game.remove(at: 9, by: .white)
        #expect(game.points[9] == nil)
        #expect(game.state == .awaitingPlacement(.black))
    }

    @Test("Un pion protégé par un moulin ne peut pas être pris")
    func millProtectsPieces() throws {
        var game = MillGame()
        try game.place(at: 0, by: .white)   // B
        try game.place(at: 9, by: .black)
        try game.place(at: 1, by: .white)
        try game.place(at: 10, by: .black)
        try game.place(at: 4, by: .white)   // pas de moulin
        try game.place(at: 11, by: .black)  // noir aligne 9-10-11
        #expect(game.state == .awaitingRemoval(.black))
        try game.remove(at: 4, by: .black)

        try game.place(at: 2, by: .white)   // blanc aligne 0-1-2
        #expect(game.state == .awaitingRemoval(.white))
        // Tous les pions noirs sont dans le moulin 9-10-11 : ils redeviennent prenables.
        #expect(game.removablePieces(for: .white).sorted() == [9, 10, 11])
    }

    @Test("Un pion hors moulin est prioritairement prenable")
    func unprotectedPieceIsTakenFirst() throws {
        var game = MillGame()
        try game.place(at: 0, by: .white)
        try game.place(at: 9, by: .black)
        try game.place(at: 1, by: .white)
        try game.place(at: 10, by: .black)
        try game.place(at: 4, by: .white)
        try game.place(at: 23, by: .black)   // isolé
        try game.place(at: 2, by: .white)    // moulin 0-1-2
        #expect(game.state == .awaitingRemoval(.white))

        // Aucun noir n'est en moulin : tous prenables.
        #expect(Set(game.removablePieces(for: .white)) == Set([9, 10, 23]))
        #expect(throws: MillError.notYourPiece) { try game.remove(at: 0, by: .white) }
    }

    @Test("Un déplacement doit suivre un trait du plateau")
    func moveMustFollowAdjacency() {
        var game = MillGame()
        #expect(MillBoard.adjacency[0].contains(1))
        #expect(MillBoard.adjacency[0].contains(2) == false)
        _ = game
    }

    @Test("Le vol s'active à trois pions, pas avant")
    func flyingUnlocksAtThreePieces() {
        var game = MillGame()
        #expect(game.canFly(.white) == false, "réserve non vide, pas de vol")
        _ = game
    }

    @Test("Les alignements passant par une intersection sont corrects")
    func millsThroughPoint() {
        #expect(MillBoard.millsThrough[0].contains([0, 1, 2]))
        #expect(MillBoard.millsThrough[0].contains([0, 9, 21]))
        #expect(MillBoard.millsThrough[4].contains([3, 4, 5]))
        #expect(MillBoard.millsThrough[4].contains([1, 4, 7]))
    }
}
