import Testing
@testable import TronEngine

@Suite("Duel Tron")
struct TronGameTests {

    @Test("Les départs sont symétriques et face à face")
    func symmetricStart() {
        let game = TronGame(width: 40, height: 30)
        #expect(game.position(of: .cyan) == GridPoint(x: 20, y: 22), "moitié basse")
        #expect(game.position(of: .magenta) == GridPoint(x: 20, y: 7), "moitié haute")
        #expect(game.heading(of: .cyan) == .up)
        #expect(game.heading(of: .magenta) == .down)
        #expect(game.outcome == .running)
    }

    @Test("Chaque moto laisse un sillage derrière elle")
    func trailGrows() {
        var game = TronGame(width: 40, height: 30)
        #expect(game.trail(of: .cyan).count == 1)
        game.tick()
        #expect(game.trail(of: .cyan).count == 2)
        #expect(game.trail(of: .cyan).contains(GridPoint(x: 20, y: 21)))
        #expect(game.tickCount == 1)
    }

    @Test("Le demi-tour est refusé")
    func rejectsReversal() {
        var game = TronGame()
        let reversed = game.steer(.cyan, .down)
        #expect(reversed == false, "cyan monte, demi-tour interdit")
        #expect(game.heading(of: .cyan) == .up)

        let turned = game.steer(.cyan, .left)
        #expect(turned)
        #expect(game.heading(of: .cyan) == .left)
    }

    @Test("Sortir de l'arène fait perdre")
    func wallCollisionLoses() {
        var game = TronGame(width: 10, height: 10)
        // Les deux partent de x = 5. Cyan file à gauche, magenta à droite.
        game.steer(.cyan, .left)
        game.steer(.magenta, .right)
        for _ in 0..<10 where game.isRunning { game.tick() }
        // Cyan sort en x<0 au 6e tick, magenta en x>9 au 5e : magenta meurt en premier.
        #expect(game.outcome == .victory(.cyan))
    }

    @Test("Foncer dans un sillage fait perdre")
    func trailCollisionLoses() {
        var game = TronGame(width: 20, height: 20)
        game.tick()
        game.tick()
        // Cyan fait demi-tour par la bande : gauche, bas, droite -> retombe sur son sillage.
        game.steer(.cyan, .left);  game.tick()
        game.steer(.cyan, .down);  game.tick()
        game.steer(.cyan, .right)
        game.tick()
        #expect(game.outcome == .victory(.magenta))
    }

    @Test("Une collision frontale ne fait aucun gagnant")
    func headOnCollisionIsDraw() {
        // Distance paire sur l'axe vertical : les deux visent la même case.
        var game = TronGame(width: 20, height: 12)
        #expect(game.position(of: .cyan) == GridPoint(x: 10, y: 9))
        #expect(game.position(of: .magenta) == GridPoint(x: 10, y: 3))
        while game.isRunning { game.tick() }
        #expect(game.outcome == .draw)
    }

    @Test("Un croisement tête-bêche ne fait aucun gagnant")
    func swapCollisionIsDraw() {
        var game = TronGame(width: 20, height: 10)
        #expect(game.position(of: .cyan) == GridPoint(x: 10, y: 7))
        #expect(game.position(of: .magenta) == GridPoint(x: 10, y: 2))
        while game.isRunning { game.tick() }
        #expect(game.outcome == .draw, "distance impaire : elles échangent leurs cases")
    }

    @Test("La partie terminée ne bouge plus")
    func frozenAfterOutcome() {
        var game = TronGame(width: 20, height: 12)
        while game.isRunning { game.tick() }
        let ticks = game.tickCount
        game.tick()
        #expect(game.tickCount == ticks)
        let steered = game.steer(.cyan, .up)
        #expect(steered == false)
    }

    @Test("Les directions opposées sont cohérentes")
    func directionOpposites() {
        for direction in Direction.allCases {
            #expect(direction.opposite.opposite == direction)
            #expect(direction.opposite != direction)
        }
    }
}
