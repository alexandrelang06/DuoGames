import Testing
@testable import ChessEngine

@Suite("Lecture FEN")
struct ChessFENTests {

    @Test("La position initiale se relit correctement")
    func parsesInitialPosition() throws {
        let position = try #require(ChessPosition(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"))
        #expect(position.board == ChessBoard.initial())
        #expect(position.sideToMove == .white)
        #expect(position.castlingRights == .all)
        #expect(position.enPassantTarget == nil)
    }

    @Test("La notation algébrique est bidirectionnelle")
    func algebraicNotation() throws {
        #expect(ChessSquare("e4") == ChessSquare(4, 3))
        #expect(ChessSquare("a1") == ChessSquare(0, 0))
        #expect(ChessSquare("h8") == ChessSquare(7, 7))
        #expect(ChessSquare(4, 3).description == "e4")
        #expect(ChessSquare("i9") == nil)
    }

    @Test("Une FEN invalide est rejetée")
    func rejectsInvalidFEN() {
        #expect(ChessPosition(fen: "pas une fen") == nil)
        #expect(ChessPosition(fen: "rnbqkbnr/pppppppp/8/8 w KQkq - 0 1") == nil)
    }
}

@Suite("Règles des échecs")
struct ChessRulesTests {

    @Test("Vingt coups d'ouverture")
    func openingMoves() {
        let game = ChessGame()
        #expect(game.legalMoves.count == 20)
        #expect(game.sideToMove == .white)
        #expect(game.isInCheck == false)
    }

    @Test("Le mat du berger en quatre demi-coups")
    func foolsMate() throws {
        var game = ChessGame()
        try game.apply("f2f3")
        try game.apply("e7e5")
        try game.apply("g2g4")
        try game.apply("d8h4")
        #expect(game.outcome == .checkmate(winner: .black))
        #expect(game.isOver)
        #expect(game.legalMoves.isEmpty)
    }

    @Test("Aucun coup n'est accepté après le mat")
    func noMovesAfterMate() throws {
        var game = ChessGame()
        for move in ["f2f3", "e7e5", "g2g4", "d8h4"] { try game.apply(move) }
        #expect(throws: ChessError.gameOver) { try game.apply("e1e2") }
    }

    @Test("Le pat n'est pas un mat")
    func stalemateIsNotMate() throws {
        let position = try #require(ChessPosition(fen: "7k/5Q2/6K1/8/8/8/8/8 b - - 0 1"))
        let game = ChessGame(position: position)
        #expect(game.isInCheck == false)
        #expect(game.outcome == .stalemate)
    }

    @Test("Les deux roques sont disponibles quand la voie est libre")
    func castlingAvailable() throws {
        let position = try #require(ChessPosition(fen: "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1"))
        let game = ChessGame(position: position)
        let castles = game.legalMoves.filter(\.isCastling)
        #expect(castles.count == 2)
        #expect(Set(castles.map(\.destination)) == [ChessSquare("g1")!, ChessSquare("c1")!])
    }

    @Test("Le roque déplace aussi la tour")
    func castlingMovesRook() throws {
        let position = try #require(ChessPosition(fen: "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1"))
        var game = ChessGame(position: position)
        try game.apply("e1g1")
        #expect(game.board[ChessSquare("g1")!] == ChessPiece(.white, .king))
        #expect(game.board[ChessSquare("f1")!] == ChessPiece(.white, .rook))
        #expect(game.board[ChessSquare("h1")!] == nil)
    }

    @Test("On ne roque pas en sortant d'un échec")
    func cannotCastleOutOfCheck() throws {
        // Tour noire en e8 : le roi blanc est en échec sur la colonne e.
        let position = try #require(ChessPosition(fen: "4r3/8/8/8/8/8/8/R3K2R w KQ - 0 1"))
        let game = ChessGame(position: position)
        #expect(game.isInCheck)
        #expect(game.legalMoves.contains { $0.isCastling } == false)
    }

    @Test("On ne roque pas à travers une case attaquée")
    func cannotCastleThroughAttack() throws {
        // Tour noire en f8 : la case f1 est attaquée.
        let position = try #require(ChessPosition(fen: "5r2/8/8/8/8/8/8/R3K2R w KQ - 0 1"))
        let game = ChessGame(position: position)
        #expect(game.isInCheck == false)
        let castles = game.legalMoves.filter(\.isCastling)
        #expect(castles.map(\.destination) == [ChessSquare("c1")!], "seul le grand roque reste")
    }

    @Test("Bouger le roi supprime les droits de roque")
    func kingMoveLosesCastling() throws {
        let position = try #require(ChessPosition(fen: "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1"))
        var game = ChessGame(position: position)
        try game.apply("e1e2")
        #expect(game.position.castlingRights.contains(.whiteKingside) == false)
        #expect(game.position.castlingRights.contains(.whiteQueenside) == false)
        #expect(game.position.castlingRights.contains(.blackKingside), "les noirs conservent les leurs")
    }

    @Test("La prise en passant retire le pion qui vient de doubler")
    func enPassantCapture() throws {
        var game = ChessGame()
        try game.apply("e2e4")
        try game.apply("a7a6")
        try game.apply("e4e5")
        try game.apply("d7d5")     // ouvre la prise en passant en d6
        #expect(game.position.enPassantTarget == ChessSquare("d6"))

        try game.apply("e5d6")
        #expect(game.board[ChessSquare("d6")!] == ChessPiece(.white, .pawn))
        #expect(game.board[ChessSquare("d5")!] == nil, "le pion noir est bien retiré")
    }

    @Test("La prise en passant expire après un coup")
    func enPassantExpires() throws {
        var game = ChessGame()
        try game.apply("e2e4")
        #expect(game.position.enPassantTarget == ChessSquare("e3"))
        try game.apply("a7a6")
        #expect(game.position.enPassantTarget == nil)
    }

    @Test("La promotion offre quatre pièces")
    func promotionOffersFourPieces() throws {
        let position = try #require(ChessPosition(fen: "8/P6k/8/8/8/8/8/K7 w - - 0 1"))
        let game = ChessGame(position: position)
        let promotions = game.legalMoves.filter { $0.promotion != nil }
        #expect(promotions.count == 4)
        #expect(Set(promotions.compactMap(\.promotion)) == [.queen, .rook, .bishop, .knight])
    }

    @Test("Une promotion sans pièce choisie est refusée")
    func promotionRequiresChoice() throws {
        let position = try #require(ChessPosition(fen: "8/P6k/8/8/8/8/8/K7 w - - 0 1"))
        var game = ChessGame(position: position)
        #expect(throws: ChessError.promotionRequired) { try game.apply("a7a8") }
        try game.apply("a7a8q")
        #expect(game.board[ChessSquare("a8")!] == ChessPiece(.white, .queen))
    }

    @Test("Un coup qui laisse son roi en échec est illégal")
    func cannotExposeOwnKing() throws {
        // Le cavalier d2 est cloué par la tour noire e8 sur le roi e1.
        let position = try #require(ChessPosition(fen: "4r2k/8/8/8/8/8/4N3/4K3 w - - 0 1"))
        let game = ChessGame(position: position)
        #expect(game.legalMoves.contains { $0.origin == ChessSquare("e2") } == false,
                "la pièce clouée ne peut pas bouger")
    }

    @Test("Roi contre roi : matériel insuffisant")
    func insufficientMaterial() throws {
        let position = try #require(ChessPosition(fen: "8/8/8/4k3/8/8/4K3/8 w - - 0 1"))
        let game = ChessGame(position: position)
        #expect(game.outcome == .insufficientMaterial)
    }

    @Test("Roi et fou contre roi : matériel insuffisant")
    func kingAndBishopInsufficient() throws {
        let position = try #require(ChessPosition(fen: "8/8/8/4k3/8/8/4KB2/8 w - - 0 1"))
        let game = ChessGame(position: position)
        #expect(game.hasInsufficientMaterial)
    }

    @Test("Une tour suffit à mater : matériel suffisant")
    func kingAndRookIsSufficient() throws {
        let position = try #require(ChessPosition(fen: "8/8/8/4k3/8/8/4KR2/8 w - - 0 1"))
        let game = ChessGame(position: position)
        #expect(game.hasInsufficientMaterial == false)
        #expect(game.outcome == .ongoing)
    }
}
