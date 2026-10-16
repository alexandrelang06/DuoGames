import Testing
@testable import ChessEngine

/// Perft : compte des feuilles de l'arbre de coups, comparé aux valeurs publiées.
/// C'est le seul test qui prouve vraiment qu'un générateur d'échecs est correct —
/// roque, prise en passant et promotion inclus.
@Suite("Perft")
struct ChessPerftTests {

    @Test("Position initiale, profondeurs 1 à 3")
    func perftInitial() {
        let position = ChessPosition()
        #expect(ChessGame.perft(position, depth: 1) == 20)
        #expect(ChessGame.perft(position, depth: 2) == 400)
        #expect(ChessGame.perft(position, depth: 3) == 8_902)
    }

    @Test("Kiwipete : roques, prises en passant, clouages")
    func perftKiwipete() throws {
        let fen = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1"
        let position = try #require(ChessPosition(fen: fen))
        #expect(ChessGame.perft(position, depth: 1) == 48)
        #expect(ChessGame.perft(position, depth: 2) == 2_039)
    }

    @Test("Position 3 : finale de pions et prise en passant")
    func perftPosition3() throws {
        let fen = "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1"
        let position = try #require(ChessPosition(fen: fen))
        #expect(ChessGame.perft(position, depth: 1) == 14)
        #expect(ChessGame.perft(position, depth: 2) == 191)
        #expect(ChessGame.perft(position, depth: 3) == 2_812)
    }

    @Test("Position 4 : promotions sous échec")
    func perftPosition4() throws {
        let fen = "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1"
        let position = try #require(ChessPosition(fen: fen))
        #expect(ChessGame.perft(position, depth: 1) == 6)
        #expect(ChessGame.perft(position, depth: 2) == 264)
    }
}
