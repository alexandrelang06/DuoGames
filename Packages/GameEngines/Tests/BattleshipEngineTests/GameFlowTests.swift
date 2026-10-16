import Testing
@testable import BattleshipEngine

/// Pose une flotte complète et légale, en lignes horizontales successives.
/// Les navires occupent les lignes 0 à 4 ; les lignes 5 à 9 restent vides.
private func completeFleet(on game: inout BattleshipGame, for player: Player) throws {
    for (index, kind) in ShipKind.allCases.enumerated() {
        try game.place(
            ShipPlacement(kind: kind, origin: Coordinate(x: 0, y: index), orientation: .horizontal),
            for: player
        )
    }
}

/// Amène la partie en phase de tir, les deux flottes posées. Le joueur A ouvre le feu.
private func startedGame() throws -> BattleshipGame {
    var game = BattleshipGame()
    try completeFleet(on: &game, for: .a)
    try game.confirmFleet(for: .a)
    try game.acknowledgeHandover()
    try completeFleet(on: &game, for: .b)
    try game.confirmFleet(for: .b)
    return game
}

/// Toutes les cases occupées par une flotte posée par `completeFleet`.
private var fleetCells: [Coordinate] {
    ShipKind.allCases.enumerated().flatMap { index, kind in
        (0..<kind.length).map { Coordinate(x: $0, y: index) }
    }
}

/// Une case vide distincte à chaque appel, pour qu'un joueur puisse rendre la main sans toucher.
private func emptyCell(_ index: Int) -> Coordinate {
    Coordinate(x: index % 10, y: 5 + (index / 10))
}

@Suite("Déroulé de la partie")
struct GameFlowTests {

    @Test("La partie commence par le placement du joueur A")
    func initialPhase() {
        let game = BattleshipGame()
        #expect(game.phase == .placement(.a))
        #expect(game.phase.isPrivacyScreenVisible == false)
    }

    @Test("Un joueur ne peut pas placer pendant le tour de l'autre")
    func rejectsPlacementOutOfTurn() {
        var game = BattleshipGame()
        let placement = ShipPlacement(kind: .destroyer, origin: Coordinate(x: 0, y: 0), orientation: .horizontal)
        #expect(throws: GameError.notYourTurn(expected: .a)) {
            try game.place(placement, for: .b)
        }
    }

    @Test("Valider une flotte incomplète est refusé")
    func rejectsIncompleteFleet() throws {
        var game = BattleshipGame()
        try game.place(
            ShipPlacement(kind: .destroyer, origin: Coordinate(x: 0, y: 0), orientation: .horizontal),
            for: .a
        )
        #expect(throws: (any Error).self) { try game.confirmFleet(for: .a) }
    }

    @Test("Le carton de confidentialité s'intercale entre les deux placements")
    func handoverProtectsPrivacy() throws {
        var game = BattleshipGame()
        try completeFleet(on: &game, for: .a)
        try game.confirmFleet(for: .a)

        // Plan B (FOLDABLE.md Q1) : l'écran masque tout pendant l'échange.
        #expect(game.phase == .handover(to: .b))
        #expect(game.phase.isPrivacyScreenVisible)

        try game.acknowledgeHandover()
        #expect(game.phase == .placement(.b))
        #expect(game.phase.isPrivacyScreenVisible == false)
    }

    @Test("Le joueur qui a placé en premier ouvre le feu")
    func firstPlacerFiresFirst() throws {
        let game = try startedGame()
        #expect(game.phase == .firing(.a))
        #expect(game.startingPlayer == .a)
    }

    @Test("Tirer avant la fin du placement est refusé")
    func rejectsFiringDuringPlacement() {
        var game = BattleshipGame()
        #expect(throws: GameError.wrongPhase) {
            try game.fire(at: Coordinate(x: 0, y: 0))
        }
    }

    @Test("Un tir dans l'eau passe la main")
    func missPassesTurn() throws {
        var game = try startedGame()
        let outcome = try game.fire(at: emptyCell(0))
        #expect(outcome == .miss)
        #expect(outcome.didConsumeTurn)
        #expect(game.phase == .firing(.b))
    }

    @Test("Un tir touché passe aussi la main")
    func hitPassesTurn() throws {
        var game = try startedGame()
        let outcome = try game.fire(at: Coordinate(x: 0, y: 0))
        #expect(outcome == .hit(.carrier))
        #expect(game.phase == .firing(.b))
    }

    @Test("Un tir touche bien la grille adverse, jamais la sienne")
    func shotsLandOnOpponentBoard() throws {
        var game = try startedGame()
        _ = try game.fire(at: Coordinate(x: 0, y: 0))
        #expect(game.board(for: .b).incomingShots.contains(Coordinate(x: 0, y: 0)))
        #expect(game.board(for: .a).incomingShots.isEmpty)
    }

    @Test("Retirer sur une case déjà visée ne consomme pas le tour")
    func alreadyShotDoesNotConsumeTurn() throws {
        var game = try startedGame()
        _ = try game.fire(at: emptyCell(0))   // A tire, main à B
        _ = try game.fire(at: emptyCell(1))   // B tire, main à A
        #expect(game.phase == .firing(.a))

        let repeated = try game.fire(at: emptyCell(0))
        #expect(repeated == .alreadyShot)
        #expect(repeated.didConsumeTurn == false)
        #expect(game.phase == .firing(.a), "le tour doit rester au même joueur")
    }

    @Test("Un tir hors grille est rejeté sans consommer le tour")
    func outOfBoundsShotRejected() throws {
        var game = try startedGame()
        let outcome = try game.fire(at: Coordinate(x: 42, y: 0))
        #expect(outcome == .invalid)
        #expect(outcome.didConsumeTurn == false)
        #expect(game.phase == .firing(.a))
    }

    @Test("Le dernier coup sur un navire le déclare coulé")
    func sinkingDetection() throws {
        var game = try startedGame()
        // Le destroyer occupe (0,4) et (1,4).
        let first = try game.fire(at: Coordinate(x: 0, y: 4))
        #expect(first == .hit(.destroyer))
        #expect(game.board(for: .b).isSunk(.destroyer) == false)

        _ = try game.fire(at: emptyCell(0))   // B rend la main

        let last = try game.fire(at: Coordinate(x: 1, y: 4))
        #expect(last == .sunk(.destroyer))
        #expect(game.board(for: .b).isSunk(.destroyer))
    }

    @Test("Couler toute la flotte gagne la partie")
    func victoryWhenFleetDestroyed() throws {
        var game = try startedGame()

        for (index, target) in fleetCells.enumerated() {
            _ = try game.fire(at: target)               // A frappe
            if case .victory = game.phase { break }
            _ = try game.fire(at: emptyCell(index))     // B rend la main
        }

        #expect(game.board(for: .b).isFleetDestroyed)
        #expect(game.phase == .victory(.a))
    }

    @Test("Aucun coup n'est possible après la victoire")
    func noMovesAfterVictory() throws {
        var game = try startedGame()
        for (index, target) in fleetCells.enumerated() {
            _ = try game.fire(at: target)
            if case .victory = game.phase { break }
            _ = try game.fire(at: emptyCell(index))
        }
        #expect(game.phase == .victory(.a))
        #expect(throws: GameError.wrongPhase) { try game.fire(at: Coordinate(x: 5, y: 5)) }
    }

    @Test("L'historique ne retient que les tirs qui ont consommé un tour")
    func logSkipsRejectedShots() throws {
        var game = try startedGame()
        _ = try game.fire(at: Coordinate(x: 99, y: 99))  // invalide
        _ = try game.fire(at: Coordinate(x: 0, y: 0))    // touché
        #expect(game.log.count == 1)
        #expect(game.log.first?.shooter == .a)
        #expect(game.log.first?.outcome == .hit(.carrier))
    }

    @Test("Chaque résultat de tir porte une clé d'événement pour le son et l'haptique")
    func outcomeEventKeys() {
        #expect(ShotOutcome.miss.eventKey == "battleship.miss")
        #expect(ShotOutcome.hit(.cruiser).eventKey == "battleship.hit")
        #expect(ShotOutcome.sunk(.cruiser).eventKey == "battleship.sunk")
    }
}
