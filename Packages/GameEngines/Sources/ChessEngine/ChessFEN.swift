public extension ChessPosition {

    /// Lecture d'une position en notation Forsyth-Edwards.
    /// Indispensable pour tester le moteur sur des positions de référence.
    init?(fen: String) {
        let fields = fen.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard fields.count >= 4 else { return nil }

        var board = ChessBoard()
        let ranks = fields[0].split(separator: "/").map(String.init)
        guard ranks.count == 8 else { return nil }

        for (index, rankText) in ranks.enumerated() {
            let rank = 7 - index      // la FEN commence par la 8e rangée
            var file = 0
            for character in rankText {
                if let empty = character.wholeNumberValue, (1...8).contains(empty) {
                    file += empty
                    continue
                }
                guard let piece = Self.piece(from: character), file < 8 else { return nil }
                board[ChessSquare(file, rank)] = piece
                file += 1
            }
            guard file == 8 else { return nil }
        }

        guard let side: ChessColor = fields[1] == "w" ? .white : (fields[1] == "b" ? .black : nil) else {
            return nil
        }

        var rights: CastlingRights = []
        if fields[2] != "-" {
            for character in fields[2] {
                switch character {
                case "K": rights.insert(.whiteKingside)
                case "Q": rights.insert(.whiteQueenside)
                case "k": rights.insert(.blackKingside)
                case "q": rights.insert(.blackQueenside)
                default: return nil
                }
            }
        }

        let enPassant = fields[3] == "-" ? nil : ChessSquare(fields[3])
        let halfmove = fields.count > 4 ? Int(fields[4]) ?? 0 : 0
        let fullmove = fields.count > 5 ? Int(fields[5]) ?? 1 : 1

        self.init(board: board, sideToMove: side, castlingRights: rights,
                  enPassantTarget: enPassant, halfmoveClock: halfmove, fullmoveNumber: fullmove)
    }

    private static func piece(from character: Character) -> ChessPiece? {
        let color: ChessColor = character.isUppercase ? .white : .black
        let kind: PieceKind? = switch character.lowercased() {
        case "p": .pawn
        case "n": .knight
        case "b": .bishop
        case "r": .rook
        case "q": .queen
        case "k": .king
        default: nil
        }
        return kind.map { ChessPiece(color, $0) }
    }
}
