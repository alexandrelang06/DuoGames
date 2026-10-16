import Testing
@testable import DraughtsEngine

private func makeBoard(_ setup: [(Square, DraughtsPiece)]) -> DraughtsBoard {
    var board = DraughtsBoard()
    for (square, piece) in setup { board[square] = piece }
    return board
}

private func man(_ color: DraughtsColor) -> DraughtsPiece { DraughtsPiece(color: color) }
private func king(_ color: DraughtsColor) -> DraughtsPiece { DraughtsPiece(color: color, isKing: true) }

@Suite("Damier")
struct DraughtsBoardTests {

    @Test("Position de départ : 20 pions par camp")
    func initialSetup() {
        let board = DraughtsBoard.initial()
        #expect(board.count(of: .white) == 20)
        #expect(board.count(of: .black) == 20)
    }

    @Test("Tous les pions sont sur des cases sombres")
    func piecesOnPlayableSquares() {
        let board = DraughtsBoard.initial()
        for color in DraughtsColor.allCases {
            #expect(board.pieces(of: color).allSatisfy { $0.isPlayable })
        }
    }

    @Test("Les noirs occupent le haut, les blancs le bas")
    func startingRows() {
        let board = DraughtsBoard.initial()
        #expect(board.pieces(of: .black).allSatisfy { $0.row < 4 })
        #expect(board.pieces(of: .white).allSatisfy { $0.row >= 6 })
    }

    @Test("Aucun pion n'est dame au départ")
    func noKingsAtStart() {
        let board = DraughtsBoard.initial()
        #expect(board.pieces(of: .white).allSatisfy { board[$0]?.isKing == false })
    }
}

@Suite("Coups des dames")
struct DraughtsMoveTests {

    @Test("Neuf coups d'ouverture pour les blancs")
    func openingMoves() {
        let game = DraughtsGame()
        #expect(game.sideToMove == .white)
        #expect(game.legalMoves.count == 9)
        #expect(game.legalMoves.allSatisfy { !$0.isCapture })
    }

    @Test("Le pion n'avance que vers le camp adverse")
    func manMovesForwardOnly() {
        let board = makeBoard([(Square(5, 4), man(.white)), (Square(0, 9), man(.black))])
        let game = DraughtsGame(board: board)
        let destinations = Set(game.legalMoves.map(\.destination))
        #expect(destinations == [Square(4, 3), Square(4, 5)], "vers le haut uniquement")
    }

    @Test("La prise est obligatoire")
    func captureIsMandatory() throws {
        let board = makeBoard([
            (Square(5, 4), man(.white)),
            (Square(4, 3), man(.black)),
        ])
        var game = DraughtsGame(board: board)
        #expect(game.legalMoves.count == 1)
        #expect(game.legalMoves[0].isCapture)

        let quiet = DraughtsMove(origin: Square(5, 4), path: [Square(4, 5)])
        #expect(throws: DraughtsError.captureIsMandatory) { try game.apply(quiet) }
    }

    @Test("Le pion prend aussi en arrière")
    func manCapturesBackwards() {
        let board = makeBoard([
            (Square(5, 4), man(.white)),
            (Square(6, 3), man(.black)),
        ])
        let game = DraughtsGame(board: board)
        let captures = game.legalMoves.filter(\.isCapture)
        #expect(captures.count == 1)
        #expect(captures[0].destination == Square(7, 2), "prise vers l'arrière autorisée")
    }

    @Test("La rafle la plus longue est obligatoire")
    func maximumCaptureIsMandatory() throws {
        // Un choix à 1 prise et un choix à 3 prises.
        let board = makeBoard([
            (Square(8, 3), man(.white)),
            (Square(7, 2), man(.black)),   // branche courte
            (Square(7, 4), man(.black)),   // branche longue
            (Square(5, 4), man(.black)),
            (Square(3, 2), man(.black)),
        ])
        var game = DraughtsGame(board: board)

        let all = DraughtsMoveGenerator.allCaptures(for: .white, on: board)
        #expect(all.contains { $0.captured.count == 1 }, "la branche courte existe")
        #expect(all.contains { $0.captured.count == 3 }, "la branche longue existe")

        #expect(game.legalMoves.count == 1, "seule la majorité est légale")
        #expect(game.legalMoves[0].captured.count == 3)

        let short = try #require(all.first { $0.captured.count == 1 })
        #expect(throws: DraughtsError.mustCaptureMaximum(available: 3)) { try game.apply(short) }
    }

    @Test("Un pion capturé ne peut pas l'être deux fois")
    func noDoubleCapture() {
        let board = makeBoard([
            (Square(8, 3), man(.white)),
            (Square(7, 4), man(.black)),
            (Square(5, 4), man(.black)),
            (Square(3, 2), man(.black)),
        ])
        let moves = DraughtsMoveGenerator.allCaptures(for: .white, on: board)
        for move in moves {
            #expect(Set(move.captured).count == move.captured.count, "aucun doublon dans la rafle")
        }
    }

    @Test("Atteindre la dernière rangée promeut le pion")
    func promotionOnLastRow() throws {
        let board = makeBoard([(Square(1, 2), man(.white)), (Square(9, 8), man(.black))])
        var game = DraughtsGame(board: board)
        #expect(game.legalMoves.allSatisfy { $0.promotes })

        let move = try #require(game.legalMoves.first)
        try game.apply(move)
        #expect(game.board[move.destination]?.isKing == true)
    }

    @Test("Traverser la dernière rangée en pleine rafle ne promeut pas")
    func noPromotionWhilePassingThrough() throws {
        let board = makeBoard([
            (Square(2, 5), man(.white)),
            (Square(1, 4), man(.black)),
            (Square(1, 2), man(.black)),
        ])
        var game = DraughtsGame(board: board)
        let move = try #require(game.legalMoves.first)

        #expect(move.path.contains(Square(0, 3)), "la rafle passe par la rangée de promotion")
        #expect(move.destination == Square(2, 1))
        #expect(move.promotes == false, "la promotion exige de s'y arrêter")

        try game.apply(move)
        #expect(game.board[Square(2, 1)]?.isKing == false)
    }

    @Test("La dame vole sur toute la diagonale")
    func kingFlies() {
        let board = makeBoard([(Square(5, 4), king(.white)), (Square(0, 9), man(.black))])
        let game = DraughtsGame(board: board)
        #expect(game.legalMoves.count == 16)
        #expect(game.legalMoves.allSatisfy { !$0.isCapture })
    }

    @Test("La dame prend à distance et se pose où elle veut derrière")
    func kingCapturesAtRange() {
        let board = makeBoard([
            (Square(8, 1), king(.white)),
            (Square(5, 4), man(.black)),
        ])
        let game = DraughtsGame(board: board)
        let captures = game.legalMoves
        #expect(captures.count == 5, "cinq cases d'atterrissage derrière le pion pris")
        #expect(captures.allSatisfy { $0.captured == [Square(5, 4)] })
        #expect(Set(captures.map(\.destination)) == [
            Square(4, 5), Square(3, 6), Square(2, 7), Square(1, 8), Square(0, 9),
        ])
    }
}

@Suite("Fin de partie aux dames")
struct DraughtsOutcomeTests {

    @Test("Plus aucun pion : la partie est perdue")
    func lossWhenNoPieces() throws {
        let board = makeBoard([
            (Square(5, 4), man(.white)),
            (Square(4, 3), man(.black)),
        ])
        var game = DraughtsGame(board: board)
        let capture = try #require(game.legalMoves.first)
        try game.apply(capture)
        #expect(game.board.count(of: .black) == 0)
        #expect(game.outcome == .victory(.white))
    }

    @Test("Bloqué sans coup légal : la partie est perdue")
    func lossWhenBlocked() {
        // Pion blanc collé à la rangée du fond, sans prise possible.
        let board = makeBoard([(Square(0, 1), man(.white)), (Square(9, 8), man(.black))])
        let game = DraughtsGame(board: board, sideToMove: .white)
        #expect(game.outcome == .victory(.black))
    }

    @Test("Aucun coup n'est accepté après la fin")
    func noMovesAfterEnd() throws {
        let board = makeBoard([(Square(0, 1), man(.white)), (Square(9, 8), man(.black))])
        var game = DraughtsGame(board: board)
        #expect(game.isOver)
        let bogus = DraughtsMove(origin: Square(0, 1), path: [Square(1, 2)])
        #expect(throws: DraughtsError.gameOver) { try game.apply(bogus) }
    }

    @Test("Le trait alterne après chaque coup")
    func turnAlternates() throws {
        var game = DraughtsGame()
        #expect(game.sideToMove == .white)
        try game.apply(game.legalMoves[0])
        #expect(game.sideToMove == .black)
        try game.apply(game.legalMoves[0])
        #expect(game.sideToMove == .white)
    }
}
