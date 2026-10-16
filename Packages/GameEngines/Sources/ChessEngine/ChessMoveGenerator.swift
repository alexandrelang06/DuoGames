public enum ChessMoveGenerator {

    static let rookDirections = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    static let bishopDirections = [(1, 1), (1, -1), (-1, 1), (-1, -1)]
    static let royalDirections = rookDirections + bishopDirections
    static let knightOffsets = [(1, 2), (2, 1), (2, -1), (1, -2), (-1, -2), (-2, -1), (-2, 1), (-1, 2)]

    // MARK: - Attaques

    /// La case est-elle attaquée par `color` ? Sert à détecter l'échec et à valider le roque.
    public static func isAttacked(_ square: ChessSquare, by color: ChessColor, on board: ChessBoard) -> Bool {
        // Pions : ils attaquent en diagonale, dans leur sens d'avance.
        let pawnRank = square.rank - color.pawnStep
        for dFile in [-1, 1] {
            let origin = ChessSquare(square.file + dFile, pawnRank)
            if let piece = board[origin], piece.color == color, piece.kind == .pawn { return true }
        }

        for (dFile, dRank) in knightOffsets {
            let origin = square.offset(dFile, dRank)
            if let piece = board[origin], piece.color == color, piece.kind == .knight { return true }
        }

        for (dFile, dRank) in royalDirections {
            let origin = square.offset(dFile, dRank)
            if let piece = board[origin], piece.color == color, piece.kind == .king { return true }
        }

        for (dFile, dRank) in rookDirections {
            if slidingAttacker(from: square, dFile, dRank, board: board, color: color, kinds: [.rook, .queen]) {
                return true
            }
        }
        for (dFile, dRank) in bishopDirections {
            if slidingAttacker(from: square, dFile, dRank, board: board, color: color, kinds: [.bishop, .queen]) {
                return true
            }
        }
        return false
    }

    private static func slidingAttacker(
        from square: ChessSquare, _ dFile: Int, _ dRank: Int,
        board: ChessBoard, color: ChessColor, kinds: Set<PieceKind>
    ) -> Bool {
        var scan = square.offset(dFile, dRank)
        while scan.isOnBoard {
            if let piece = board[scan] {
                return piece.color == color && kinds.contains(piece.kind)
            }
            scan = scan.offset(dFile, dRank)
        }
        return false
    }

    public static func isInCheck(_ color: ChessColor, on board: ChessBoard) -> Bool {
        guard let king = board.king(of: color) else { return false }
        return isAttacked(king, by: color.opponent, on: board)
    }

    // MARK: - Coups légaux

    /// Coups pseudo-légaux filtrés : on écarte ceux qui laissent son propre roi en échec.
    public static func legalMoves(in position: ChessPosition) -> [ChessMove] {
        pseudoLegalMoves(in: position).filter { move in
            var next = position
            apply(move, to: &next)
            return !isInCheck(position.sideToMove, on: next.board)
        }
    }

    public static func pseudoLegalMoves(in position: ChessPosition) -> [ChessMove] {
        var moves: [ChessMove] = []
        let color = position.sideToMove

        for origin in position.board.squares(of: color) {
            guard let piece = position.board[origin] else { continue }
            switch piece.kind {
            case .pawn: appendPawnMoves(from: origin, position: position, into: &moves)
            case .knight: appendStepMoves(from: origin, offsets: knightOffsets, position: position, into: &moves)
            case .king: appendStepMoves(from: origin, offsets: royalDirections, position: position, into: &moves)
            case .bishop: appendSlidingMoves(from: origin, directions: bishopDirections, position: position, into: &moves)
            case .rook: appendSlidingMoves(from: origin, directions: rookDirections, position: position, into: &moves)
            case .queen: appendSlidingMoves(from: origin, directions: royalDirections, position: position, into: &moves)
            }
        }
        appendCastlingMoves(position: position, into: &moves)
        return moves
    }

    private static func appendStepMoves(
        from origin: ChessSquare, offsets: [(Int, Int)],
        position: ChessPosition, into moves: inout [ChessMove]
    ) {
        let color = position.sideToMove
        for (dFile, dRank) in offsets {
            let destination = origin.offset(dFile, dRank)
            guard destination.isOnBoard else { continue }
            if let occupant = position.board[destination], occupant.color == color { continue }
            moves.append(ChessMove(from: origin, to: destination))
        }
    }

    private static func appendSlidingMoves(
        from origin: ChessSquare, directions: [(Int, Int)],
        position: ChessPosition, into moves: inout [ChessMove]
    ) {
        let color = position.sideToMove
        for (dFile, dRank) in directions {
            var destination = origin.offset(dFile, dRank)
            while destination.isOnBoard {
                if let occupant = position.board[destination] {
                    if occupant.color != color { moves.append(ChessMove(from: origin, to: destination)) }
                    break
                }
                moves.append(ChessMove(from: origin, to: destination))
                destination = destination.offset(dFile, dRank)
            }
        }
    }

    private static func appendPawnMoves(
        from origin: ChessSquare, position: ChessPosition, into moves: inout [ChessMove]
    ) {
        let color = position.sideToMove
        let step = color.pawnStep

        func append(_ destination: ChessSquare, isEnPassant: Bool = false) {
            if destination.rank == color.promotionRank {
                for kind in [PieceKind.queen, .rook, .bishop, .knight] {
                    moves.append(ChessMove(from: origin, to: destination, promotion: kind))
                }
            } else {
                moves.append(ChessMove(from: origin, to: destination, isEnPassant: isEnPassant))
            }
        }

        let single = origin.offset(0, step)
        if single.isOnBoard, position.board.isEmpty(single) {
            append(single)
            // Double pas depuis la rangée initiale, si les deux cases sont libres.
            let double = origin.offset(0, step * 2)
            if origin.rank == color.pawnRank, double.isOnBoard, position.board.isEmpty(double) {
                moves.append(ChessMove(from: origin, to: double))
            }
        }

        for dFile in [-1, 1] {
            let destination = origin.offset(dFile, step)
            guard destination.isOnBoard else { continue }
            if let occupant = position.board[destination], occupant.color != color {
                append(destination)
            } else if destination == position.enPassantTarget, position.board.isEmpty(destination) {
                append(destination, isEnPassant: true)
            }
        }
    }

    private static func appendCastlingMoves(position: ChessPosition, into moves: inout [ChessMove]) {
        let color = position.sideToMove
        let rank = color.homeRank
        let kingSquare = ChessSquare(4, rank)

        guard position.board[kingSquare] == ChessPiece(color, .king),
              !isAttacked(kingSquare, by: color.opponent, on: position.board) else { return }

        // Petit roque : f et g libres, et non attaquées.
        if position.castlingRights.contains(.kingside(color)),
           position.board[ChessSquare(7, rank)] == ChessPiece(color, .rook),
           position.board.isEmpty(ChessSquare(5, rank)),
           position.board.isEmpty(ChessSquare(6, rank)),
           !isAttacked(ChessSquare(5, rank), by: color.opponent, on: position.board),
           !isAttacked(ChessSquare(6, rank), by: color.opponent, on: position.board) {
            moves.append(ChessMove(from: kingSquare, to: ChessSquare(6, rank), castlingKingside: true))
        }

        // Grand roque : b, c et d libres ; seules c et d doivent être sûres.
        if position.castlingRights.contains(.queenside(color)),
           position.board[ChessSquare(0, rank)] == ChessPiece(color, .rook),
           position.board.isEmpty(ChessSquare(1, rank)),
           position.board.isEmpty(ChessSquare(2, rank)),
           position.board.isEmpty(ChessSquare(3, rank)),
           !isAttacked(ChessSquare(2, rank), by: color.opponent, on: position.board),
           !isAttacked(ChessSquare(3, rank), by: color.opponent, on: position.board) {
            moves.append(ChessMove(from: kingSquare, to: ChessSquare(2, rank), castlingKingside: false))
        }
    }

    // MARK: - Application

    /// Applique le coup sans vérifier sa légalité. Utilisé aussi pour tester l'échec.
    public static func apply(_ move: ChessMove, to position: inout ChessPosition) {
        guard let piece = position.board[move.origin] else { return }
        let color = piece.color
        let captured = position.board[move.destination]

        position.board[move.origin] = nil

        if move.isEnPassant {
            // Le pion pris n'est pas sur la case d'arrivée.
            position.board[ChessSquare(move.destination.file, move.origin.rank)] = nil
        }

        position.board[move.destination] = move.promotion.map { ChessPiece(color, $0) } ?? piece

        if let kingside = move.castlingKingside {
            let rank = color.homeRank
            let (rookFrom, rookTo) = kingside
                ? (ChessSquare(7, rank), ChessSquare(5, rank))
                : (ChessSquare(0, rank), ChessSquare(3, rank))
            position.board[rookTo] = position.board[rookFrom]
            position.board[rookFrom] = nil
        }

        // Droits de roque perdus dès que le roi ou une tour bouge, ou qu'une tour est prise.
        if piece.kind == .king {
            position.castlingRights.subtract([.kingside(color), .queenside(color)])
        }
        if piece.kind == .rook {
            if move.origin == ChessSquare(7, color.homeRank) { position.castlingRights.subtract(.kingside(color)) }
            if move.origin == ChessSquare(0, color.homeRank) { position.castlingRights.subtract(.queenside(color)) }
        }
        let enemy = color.opponent
        if move.destination == ChessSquare(7, enemy.homeRank) { position.castlingRights.subtract(.kingside(enemy)) }
        if move.destination == ChessSquare(0, enemy.homeRank) { position.castlingRights.subtract(.queenside(enemy)) }

        // Case de prise en passant, valable un seul demi-coup.
        if piece.kind == .pawn, abs(move.destination.rank - move.origin.rank) == 2 {
            position.enPassantTarget = ChessSquare(move.origin.file, move.origin.rank + color.pawnStep)
        } else {
            position.enPassantTarget = nil
        }

        if piece.kind == .pawn || captured != nil || move.isEnPassant {
            position.halfmoveClock = 0
        } else {
            position.halfmoveClock += 1
        }

        if color == .black { position.fullmoveNumber += 1 }
        position.sideToMove = enemy
    }
}
