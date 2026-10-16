public enum ChessColor: String, Sendable, Hashable, CaseIterable {
    case white
    case black

    public var opponent: ChessColor { self == .white ? .black : .white }
    public var localizationKey: String { "chess.player.\(rawValue)" }

    /// Sens d'avance des pions.
    var pawnStep: Int { self == .white ? 1 : -1 }
    var homeRank: Int { self == .white ? 0 : 7 }
    var pawnRank: Int { self == .white ? 1 : 6 }
    var promotionRank: Int { self == .white ? 7 : 0 }
    var enPassantRank: Int { self == .white ? 4 : 3 }
}

public enum PieceKind: String, Sendable, Hashable, CaseIterable {
    case pawn, knight, bishop, rook, queen, king

    public var localizationKey: String { "chess.piece.\(rawValue)" }

    /// Valeur indicative, utilisée pour le matériel insuffisant et l'affichage.
    public var value: Int {
        switch self {
        case .pawn: 1
        case .knight, .bishop: 3
        case .rook: 5
        case .queen: 9
        case .king: 0
        }
    }
}

public struct ChessPiece: Sendable, Hashable {
    public let color: ChessColor
    public let kind: PieceKind

    public init(_ color: ChessColor, _ kind: PieceKind) {
        self.color = color
        self.kind = kind
    }
}

public struct ChessSquare: Hashable, Sendable, CustomStringConvertible {
    public let file: Int   // 0 = colonne a
    public let rank: Int   // 0 = rangée 1

    public init(_ file: Int, _ rank: Int) {
        self.file = file
        self.rank = rank
    }

    /// Depuis la notation algébrique, « e4 ».
    public init?(_ algebraic: String) {
        let characters = Array(algebraic.lowercased())
        guard characters.count == 2,
              let fileScalar = characters[0].asciiValue,
              let rankScalar = characters[1].asciiValue else { return nil }
        let file = Int(fileScalar) - 97
        let rank = Int(rankScalar) - 49
        guard (0..<8).contains(file), (0..<8).contains(rank) else { return nil }
        self.init(file, rank)
    }

    public var isOnBoard: Bool { (0..<8).contains(file) && (0..<8).contains(rank) }

    public func offset(_ dFile: Int, _ dRank: Int) -> ChessSquare {
        ChessSquare(file + dFile, rank + dRank)
    }

    public var description: String {
        guard isOnBoard else { return "(\(file),\(rank))" }
        return "\(Character(UnicodeScalar(UInt8(97 + file))))\(rank + 1)"
    }
}

public struct CastlingRights: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let whiteKingside = CastlingRights(rawValue: 1 << 0)
    public static let whiteQueenside = CastlingRights(rawValue: 1 << 1)
    public static let blackKingside = CastlingRights(rawValue: 1 << 2)
    public static let blackQueenside = CastlingRights(rawValue: 1 << 3)
    public static let all: CastlingRights = [.whiteKingside, .whiteQueenside, .blackKingside, .blackQueenside]

    static func kingside(_ color: ChessColor) -> CastlingRights {
        color == .white ? .whiteKingside : .blackKingside
    }
    static func queenside(_ color: ChessColor) -> CastlingRights {
        color == .white ? .whiteQueenside : .blackQueenside
    }
}

public struct ChessBoard: Sendable, Hashable {
    private var squares: [ChessPiece?]

    public init() {
        squares = Array(repeating: nil, count: 64)
    }

    public static func initial() -> ChessBoard {
        var board = ChessBoard()
        let backRank: [PieceKind] = [.rook, .knight, .bishop, .queen, .king, .bishop, .knight, .rook]
        for file in 0..<8 {
            board[ChessSquare(file, 0)] = ChessPiece(.white, backRank[file])
            board[ChessSquare(file, 1)] = ChessPiece(.white, .pawn)
            board[ChessSquare(file, 6)] = ChessPiece(.black, .pawn)
            board[ChessSquare(file, 7)] = ChessPiece(.black, backRank[file])
        }
        return board
    }

    public subscript(square: ChessSquare) -> ChessPiece? {
        get {
            guard square.isOnBoard else { return nil }
            return squares[square.rank * 8 + square.file]
        }
        set {
            guard square.isOnBoard else { return }
            squares[square.rank * 8 + square.file] = newValue
        }
    }

    public func isEmpty(_ square: ChessSquare) -> Bool {
        square.isOnBoard && self[square] == nil
    }

    public func squares(of color: ChessColor) -> [ChessSquare] {
        (0..<64).compactMap { index in
            let square = ChessSquare(index % 8, index / 8)
            return self[square]?.color == color ? square : nil
        }
    }

    public func king(of color: ChessColor) -> ChessSquare? {
        squares(of: color).first { self[$0]?.kind == .king }
    }

    public func pieces(of color: ChessColor) -> [ChessPiece] {
        squares(of: color).compactMap { self[$0] }
    }
}
