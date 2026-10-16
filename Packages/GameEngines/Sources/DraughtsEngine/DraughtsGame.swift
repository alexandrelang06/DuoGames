public enum DraughtsOutcome: Sendable, Equatable {
    case ongoing
    case victory(DraughtsColor)
    case draw
}

public enum DraughtsError: Error, Equatable, Sendable {
    case gameOver
    case notYourTurn(expected: DraughtsColor)
    case illegalMove
    /// Une prise est disponible : elle est obligatoire.
    case captureIsMandatory
    /// Une rafle plus longue existe : la majorité est obligatoire.
    case mustCaptureMaximum(available: Int)
}

public struct DraughtsGame: Sendable, Equatable {
    public private(set) var board: DraughtsBoard
    public private(set) var sideToMove: DraughtsColor
    public private(set) var outcome: DraughtsOutcome
    /// Demi-coups sans prise ni mouvement de pion. Sert à la nulle.
    public private(set) var idlePlies: Int

    /// 25 coups de chaque camp sans prise ni avance de pion.
    public static let idlePlyLimit = 50

    public init(board: DraughtsBoard = .initial(), sideToMove: DraughtsColor = .white) {
        self.board = board
        self.sideToMove = sideToMove
        self.outcome = .ongoing
        self.idlePlies = 0
        refreshOutcome()
    }

    public var legalMoves: [DraughtsMove] {
        guard outcome == .ongoing else { return [] }
        return DraughtsMoveGenerator.legalMoves(for: sideToMove, on: board)
    }

    public func legalMoves(from origin: Square) -> [DraughtsMove] {
        legalMoves.filter { $0.origin == origin }
    }

    public var isOver: Bool { outcome != .ongoing }

    @discardableResult
    public mutating func apply(_ move: DraughtsMove) throws -> DraughtsMove {
        guard outcome == .ongoing else { throw DraughtsError.gameOver }

        let legal = legalMoves
        guard legal.contains(move) else {
            // Diagnostic précis : c'est la règle la plus mal comprise du jeu.
            let allCaptures = DraughtsMoveGenerator.allCaptures(for: sideToMove, on: board)
            if !allCaptures.isEmpty, !move.isCapture {
                throw DraughtsError.captureIsMandatory
            }
            if let best = allCaptures.map(\.captured.count).max(),
               move.isCapture, move.captured.count < best {
                throw DraughtsError.mustCaptureMaximum(available: best)
            }
            throw DraughtsError.illegalMove
        }

        guard let piece = board[move.origin] else { throw DraughtsError.illegalMove }

        board[move.origin] = nil
        for square in move.captured { board[square] = nil }
        board[move.destination] = move.promotes ? piece.promoted() : piece

        if move.isCapture || !piece.isKing {
            idlePlies = 0
        } else {
            idlePlies += 1
        }

        sideToMove = sideToMove.opponent
        refreshOutcome()
        return move
    }

    private mutating func refreshOutcome() {
        if board.count(of: sideToMove) == 0 {
            outcome = .victory(sideToMove.opponent)
            return
        }
        if DraughtsMoveGenerator.legalMoves(for: sideToMove, on: board).isEmpty {
            // Bloqué : dans les règles internationales, le joueur qui ne peut plus jouer perd.
            outcome = .victory(sideToMove.opponent)
            return
        }
        if idlePlies >= Self.idlePlyLimit {
            outcome = .draw
            return
        }
        outcome = .ongoing
    }
}
