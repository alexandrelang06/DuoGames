public struct ChessMove: Sendable, Hashable {
    public let origin: ChessSquare
    public let destination: ChessSquare
    /// Pièce choisie lors d'une promotion.
    public let promotion: PieceKind?
    public let isEnPassant: Bool
    /// Roque : `true` côté roi, `false` côté dame, `nil` si ce n'est pas un roque.
    public let castlingKingside: Bool?

    public init(
        from origin: ChessSquare,
        to destination: ChessSquare,
        promotion: PieceKind? = nil,
        isEnPassant: Bool = false,
        castlingKingside: Bool? = nil
    ) {
        self.origin = origin
        self.destination = destination
        self.promotion = promotion
        self.isEnPassant = isEnPassant
        self.castlingKingside = castlingKingside
    }

    public var isCastling: Bool { castlingKingside != nil }

    public var description: String {
        "\(origin)\(destination)\(promotion.map { String($0.rawValue.prefix(1)) } ?? "")"
    }
}

/// Position complète : le plateau ne suffit pas, il faut aussi les droits de roque,
/// la case de prise en passant et les compteurs de nulle.
public struct ChessPosition: Sendable, Hashable {
    public var board: ChessBoard
    public var sideToMove: ChessColor
    public var castlingRights: CastlingRights
    /// Case traversée par un pion venant d'avancer de deux, prenable en passant.
    public var enPassantTarget: ChessSquare?
    /// Demi-coups depuis la dernière prise ou avance de pion. Nulle à 100.
    public var halfmoveClock: Int
    public var fullmoveNumber: Int

    public init(
        board: ChessBoard = .initial(),
        sideToMove: ChessColor = .white,
        castlingRights: CastlingRights = .all,
        enPassantTarget: ChessSquare? = nil,
        halfmoveClock: Int = 0,
        fullmoveNumber: Int = 1
    ) {
        self.board = board
        self.sideToMove = sideToMove
        self.castlingRights = castlingRights
        self.enPassantTarget = enPassantTarget
        self.halfmoveClock = halfmoveClock
        self.fullmoveNumber = fullmoveNumber
    }

    /// Clé de répétition : deux positions sont identiques si plateau, trait, roques
    /// et prise en passant coïncident. Les compteurs n'en font pas partie.
    public var repetitionKey: RepetitionKey {
        RepetitionKey(board: board, sideToMove: sideToMove,
                      castlingRights: castlingRights, enPassantTarget: enPassantTarget)
    }

    public struct RepetitionKey: Hashable, Sendable {
        let board: ChessBoard
        let sideToMove: ChessColor
        let castlingRights: CastlingRights
        let enPassantTarget: ChessSquare?
    }
}
