import Testing
@testable import AirHockeyEngine

private let table = TableSpec(width: 400, height: 700, goalWidth: 160, puckRadius: 14, malletRadius: 26)

/// Simule jusqu'à ce qu'un événement attendu survienne, ou abandonne.
private func simulate(
    _ game: inout AirHockeyGame,
    seconds: Double = 8,
    step: Double = 1.0 / 120,
    until predicate: (AirHockeyEvent) -> Bool
) -> AirHockeyEvent? {
    var elapsed = 0.0
    while elapsed < seconds {
        for event in game.tick(step) where predicate(event) { return event }
        elapsed += step
    }
    return nil
}

@Suite("Table d'air hockey")
struct AirHockeyTableTests {

    @Test("La bouche des buts est centrée")
    func goalMouthCentred() {
        #expect(table.goalMinX == 120)
        #expect(table.goalMaxX == 280)
        #expect(table.isWithinGoalMouth(x: 200))
        #expect(table.isWithinGoalMouth(x: 50) == false)
    }

    @Test("Score à zéro et palet au centre au coup d'envoi")
    func initialState() {
        let game = AirHockeyGame(spec: table)
        #expect(game.score(.near) == 0)
        #expect(game.score(.far) == 0)
        #expect(game.puckPosition.x == table.width / 2)
        #expect(game.isOver == false)
    }
}

@Suite("Maillets")
struct AirHockeyMalletTests {

    @Test("Le maillet ne franchit jamais le pli")
    func malletStaysInOwnHalf() {
        var game = AirHockeyGame(spec: table)

        let nearIntrusion = game.moveMallet(.near, to: Vector2D(x: 200, y: 10))
        #expect(nearIntrusion.y >= table.midY, "le joueur du bas reste sous le pli")

        let farIntrusion = game.moveMallet(.far, to: Vector2D(x: 200, y: 690))
        #expect(farIntrusion.y <= table.midY, "le joueur du haut reste au-dessus")
    }

    @Test("Le maillet reste dans les bandes")
    func malletStaysInBounds() {
        var game = AirHockeyGame(spec: table)
        let clamped = game.moveMallet(.near, to: Vector2D(x: -500, y: 600))
        #expect(clamped.x == table.malletRadius)

        let other = game.moveMallet(.near, to: Vector2D(x: 5_000, y: 600))
        #expect(other.x == table.width - table.malletRadius)
    }

    @Test("Frapper le palet avec le maillet le renvoie")
    func malletHitsPuck() {
        var game = AirHockeyGame(spec: table)
        game.moveMallet(.near, to: Vector2D(x: 200, y: 420))
        // Palet lancé vers le maillet.
        game.launch(from: Vector2D(x: 200, y: 380), velocity: Vector2D(x: 0, y: 100))

        let bounced = simulate(&game, seconds: 2) { $0 == .bounce }
        #expect(bounced == .bounce)
        #expect(game.puckVelocity.y < 0, "le palet repart vers l'autre camp")
    }
}

@Suite("Physique du palet")
struct AirHockeyPhysicsTests {

    @Test("Le palet rebondit sur les bandes latérales")
    func bouncesOffSideWalls() {
        var game = AirHockeyGame(spec: table)
        game.launch(from: Vector2D(x: 200, y: 350), velocity: Vector2D(x: -600, y: 0))

        let bounced = simulate(&game, seconds: 3) { $0 == .bounce }
        #expect(bounced == .bounce)
        #expect(game.puckVelocity.x > 0, "il repart dans l'autre sens")
        #expect(game.puckPosition.x >= table.puckRadius, "il ne sort jamais de la table")
    }

    @Test("Le palet rebondit sur le fond hors de la cage")
    func bouncesOffEndWallOutsideGoal() {
        var game = AirHockeyGame(spec: table)
        // Trajectoire vers le fond, mais décalée hors de la bouche du but.
        game.launch(from: Vector2D(x: 40, y: 350), velocity: Vector2D(x: 0, y: -600))

        let bounced = simulate(&game, seconds: 3) { $0 == .bounce }
        #expect(bounced == .bounce)
        #expect(game.score(.near) == 0, "hors cage, ce n'est pas un but")
        #expect(game.puckVelocity.y > 0)
    }

    @Test("Le frottement finit par ralentir le palet")
    func frictionSlowsPuck() {
        var game = AirHockeyGame(spec: table)
        game.launch(from: Vector2D(x: 200, y: 350), velocity: Vector2D(x: 0, y: 40))
        let initial = game.puckVelocity.magnitude
        for _ in 0..<120 { game.tick(1.0 / 120) }
        #expect(game.puckVelocity.magnitude < initial)
    }

    @Test("La vitesse est plafonnée")
    func speedIsClamped() {
        var game = AirHockeyGame(spec: table)
        game.launch(from: Vector2D(x: 200, y: 350), velocity: Vector2D(x: 0, y: 99_999))
        game.tick(1.0 / 120)
        #expect(game.puckVelocity.magnitude <= AirHockeyGame.maxSpeed + 1)
    }

    @Test("Un palet immobilisé sur le pli est relancé")
    func stalledPuckOnFoldIsRelaunched() {
        var game = AirHockeyGame(spec: table)
        // Quasi immobile, pile sur l'axe du pli : il y deviendrait invisible.
        game.launch(from: Vector2D(x: 200, y: table.midY), velocity: Vector2D(x: 1, y: 0))

        let relaunched = simulate(&game, seconds: 1) { $0 == .relaunchedFromFold }
        #expect(relaunched == .relaunchedFromFold)
        #expect(game.puckVelocity.magnitude > AirHockeyGame.stallSpeed)
    }

    @Test("La pause fige la simulation")
    func pauseFreezesSimulation() {
        var game = AirHockeyGame(spec: table)
        game.launch(from: Vector2D(x: 200, y: 350), velocity: Vector2D(x: 0, y: 300))
        game.togglePause()
        let frozen = game.puckPosition
        for _ in 0..<60 { game.tick(1.0 / 120) }
        #expect(game.puckPosition == frozen)
    }
}

@Suite("Score de l'air hockey")
struct AirHockeyScoringTests {

    @Test("Entrer dans la cage marque un but")
    func goalIsScored() {
        var game = AirHockeyGame(spec: table)
        game.moveMallet(.far, to: Vector2D(x: 40, y: 105))   // gardien écarté
        game.launch(from: Vector2D(x: 200, y: 350), velocity: Vector2D(x: 0, y: -600))

        let goal = simulate(&game, seconds: 4) { if case .goal = $0 { return true }; return false }
        #expect(goal == .goal(.near), "le but du haut est celui du joueur éloigné")
        #expect(game.score(.near) == 1)
    }

    @Test("Le match s'arrête au nombre de buts convenu")
    func matchEndsAtTarget() {
        var game = AirHockeyGame(spec: table, goalsToWin: 2)
        game.moveMallet(.far, to: Vector2D(x: 40, y: 105))
        for _ in 0..<2 {
            game.launch(from: Vector2D(x: 200, y: 350), velocity: Vector2D(x: 0, y: -600))
            _ = simulate(&game, seconds: 4) { if case .goal = $0 { return true }; return false }
        }
        #expect(game.score(.near) == 2)
        #expect(game.winner == .near)
        #expect(game.isOver)
    }

    @Test("Rien ne bouge après la fin du match")
    func frozenAfterMatch() {
        var game = AirHockeyGame(spec: table, goalsToWin: 1)
        game.moveMallet(.far, to: Vector2D(x: 40, y: 105))
        game.launch(from: Vector2D(x: 200, y: 350), velocity: Vector2D(x: 0, y: -600))
        _ = simulate(&game, seconds: 4) { if case .goal = $0 { return true }; return false }
        #expect(game.isOver)

        let events = game.tick(1.0 / 120)
        #expect(events.isEmpty)
    }

    @Test("Un maillet posté devant sa cage arrête le tir")
    func malletDefendsGoal() {
        var game = AirHockeyGame(spec: table)
        game.moveMallet(.far, to: Vector2D(x: 200, y: 105))   // gardien en place
        game.launch(from: Vector2D(x: 200, y: 350), velocity: Vector2D(x: 0, y: -600))

        let goal = simulate(&game, seconds: 4) { if case .goal = $0 { return true }; return false }
        #expect(goal == nil, "le tir droit sur le gardien ne rentre pas")
        #expect(game.score(.near) == 0)
    }

    @Test("Après un but, le palet attend figé dans le camp de celui qui a encaissé")
    func puckIsFrozenOnConcederSideAfterGoal() {
        var game = AirHockeyGame(spec: table)
        game.moveMallet(.far, to: Vector2D(x: 40, y: 105))   // gardien écarté
        game.launch(from: Vector2D(x: 200, y: 350), velocity: Vector2D(x: 0, y: -600))
        _ = simulate(&game, seconds: 4) { if case .goal = $0 { return true }; return false }

        // near a marqué dans le but du haut : far a encaissé, le palet est dans la moitié haute.
        #expect(game.score(.near) == 1)
        #expect(game.puckPosition.y < table.midY, "dans le camp du joueur qui a encaissé")
        #expect(game.puckPosition.x == table.width / 2, "centré en largeur")
        #expect(game.puckVelocity.magnitude == 0, "figé, il attend d'être frappé")
    }

    @Test("Un palet figé hors du pli ne se relance pas tout seul")
    func frozenPuckStaysPut() {
        var game = AirHockeyGame(spec: table)
        game.serve(to: .near)
        let start = game.puckPosition
        for _ in 0..<120 { game.tick(1.0 / 120) }
        #expect(game.puckPosition == start, "aucun mouvement sans frappe")
        #expect(game.puckVelocity.magnitude == 0)
    }

    @Test("Chaque événement porte une clé pour le son et l'haptique")
    func eventKeys() {
        #expect(AirHockeyEvent.bounce.eventKey == "airhockey.bounce")
        #expect(AirHockeyEvent.goal(.near).eventKey == "airhockey.goal")
        #expect(AirHockeyEvent.matchOver(winner: .far).eventKey == "airhockey.victory")
    }
}
