public enum ChessOutcome: Sendable, Equatable {
    case ongoing
    case checkmate(winner: ChessColor)
    case stalemate
    /// 50 coups sans prise ni mouvement de pion.
    case fiftyMoveRule
    case threefoldRepetition
    case insufficientMaterial
}

public enum ChessError: Error, Equatable, Sendable {
    case gameOver
    case illegalMove
    /// Une promotion doit préciser la pièce choisie.
    case promotionRequired
}

public struct ChessGame: Sendable {
    public private(set) var position: ChessPosition
    public private(set) var history: [ChessMove]
    public private(set) var outcome: ChessOutcome
    private var repetitions: [ChessPosition.RepetitionKey: Int]

    public init(position: ChessPosition = ChessPosition()) {
        self.position = position
        self.history = []
        self.outcome = .ongoing
        self.repetitions = [position.repetitionKey: 1]
        refreshOutcome()
    }

    public var sideToMove: ChessColor { position.sideToMove }
    public var board: ChessBoard { position.board }
    public var isOver: Bool { outcome != .ongoing }

    public var isInCheck: Bool {
        ChessMoveGenerator.isInCheck(position.sideToMove, on: position.board)
    }

    public var legalMoves: [ChessMove] {
        guard outcome == .ongoing else { return [] }
        return ChessMoveGenerator.legalMoves(in: position)
    }

    public func legalMoves(from origin: ChessSquare) -> [ChessMove] {
        legalMoves.filter { $0.origin == origin }
    }

    @discardableResult
    public mutating func apply(_ move: ChessMove) throws -> ChessMove {
        guard outcome == .ongoing else { throw ChessError.gameOver }
        guard legalMoves.contains(move) else { throw ChessError.illegalMove }

        ChessMoveGenerator.apply(move, to: &position)
        history.append(move)
        repetitions[position.repetitionKey, default: 0] += 1
        refreshOutcome()
        return move
    }

    /// Joue un coup depuis la notation « e2e4 », avec promotion optionnelle « e7e8q ».
    @discardableResult
    public mutating func apply(_ notation: String) throws -> ChessMove {
        guard outcome == .ongoing else { throw ChessError.gameOver }
        guard notation.count >= 4,
              let origin = ChessSquare(String(notation.prefix(2))),
              let destination = ChessSquare(String(notation.dropFirst(2).prefix(2)))
        else { throw ChessError.illegalMove }

        let candidates = legalMoves.filter { $0.origin == origin && $0.destination == destination }
        guard !candidates.isEmpty else { throw ChessError.illegalMove }

        if candidates.count > 1 {
            // Plusieurs coups possibles : c'est une promotion, il faut choisir.
            guard let suffix = notation.dropFirst(4).first,
                  let kind = Self.promotionKind(suffix),
                  let move = candidates.first(where: { $0.promotion == kind })
            else { throw ChessError.promotionRequired }
            return try apply(move)
        }
        return try apply(candidates[0])
    }

    private static func promotionKind(_ character: Character) -> PieceKind? {
        switch character.lowercased() {
        case "q": .queen
        case "r": .rook
        case "b": .bishop
        case "n": .knight
        default: nil
        }
    }

    private mutating func refreshOutcome() {
        if ChessMoveGenerator.legalMoves(in: position).isEmpty {
            outcome = ChessMoveGenerator.isInCheck(position.sideToMove, on: position.board)
                ? .checkmate(winner: position.sideToMove.opponent)
                : .stalemate
            return
        }
        if position.halfmoveClock >= 100 {
            outcome = .fiftyMoveRule
            return
        }
        if (repetitions[position.repetitionKey] ?? 0) >= 3 {
            outcome = .threefoldRepetition
            return
        }
        if hasInsufficientMaterial {
            outcome = .insufficientMaterial
            return
        }
        outcome = .ongoing
    }

    /// Roi seul, roi et fou, roi et cavalier : personne ne peut mater.
    public var hasInsufficientMaterial: Bool {
        var minorPieces = 0
        for color in ChessColor.allCases {
            for piece in position.board.pieces(of: color) {
                switch piece.kind {
                case .king: continue
                case .pawn, .rook, .queen: return false
                case .knight, .bishop: minorPieces += 1
                }
            }
        }
        return minorPieces <= 1
    }
}

// MARK: - Perft

public extension ChessGame {
    /// Compte les feuilles de l'arbre de coups à une profondeur donnée.
    ///
    /// C'est le test de référence d'un générateur d'échecs : les valeurs attendues sont
    /// publiées et connues, la moindre erreur sur le roque, la prise en passant ou la
    /// promotion se voit immédiatement.
    static func perft(_ position: ChessPosition, depth: Int) -> Int {
        guard depth > 0 else { return 1 }
        let moves = ChessMoveGenerator.legalMoves(in: position)
        if depth == 1 { return moves.count }

        var total = 0
        for move in moves {
            var next = position
            ChessMoveGenerator.apply(move, to: &next)
            total += perft(next, depth: depth - 1)
        }
        return total
    }
}
