/// Jeu de dames international : damier 10×10, 20 pions par camp,
/// prise obligatoire à la majorité, dames volantes.

public enum DraughtsColor: String, Sendable, Hashable, CaseIterable {
    case white
    case black

    public var opponent: DraughtsColor { self == .white ? .black : .white }
    public var localizationKey: String { "draughts.player.\(rawValue)" }

    /// Les blancs remontent le damier, les noirs le descendent.
    var forwardStep: Int { self == .white ? -1 : 1 }
    /// Rangée de promotion.
    var promotionRow: Int { self == .white ? 0 : DraughtsBoard.size - 1 }
}

public struct DraughtsPiece: Sendable, Hashable {
    public let color: DraughtsColor
    public let isKing: Bool

    public init(color: DraughtsColor, isKing: Bool = false) {
        self.color = color
        self.isKing = isKing
    }

    public func promoted() -> DraughtsPiece { DraughtsPiece(color: color, isKing: true) }
}

public struct Square: Hashable, Sendable, CustomStringConvertible {
    public let row: Int
    public let col: Int

    public init(_ row: Int, _ col: Int) {
        self.row = row
        self.col = col
    }

    public var isOnBoard: Bool {
        (0..<DraughtsBoard.size).contains(row) && (0..<DraughtsBoard.size).contains(col)
    }

    /// Seules les cases sombres sont jouables.
    public var isPlayable: Bool { isOnBoard && (row + col) % 2 == 1 }

    public func offset(_ dRow: Int, _ dCol: Int) -> Square {
        Square(row + dRow, col + dCol)
    }

    /// Notation internationale : les 50 cases sombres numérotées de 1 à 50.
    public var description: String {
        guard isPlayable else { return "(\(row),\(col))" }
        return "\(row * (DraughtsBoard.size / 2) + col / 2 + 1)"
    }
}

public struct DraughtsBoard: Sendable, Equatable {
    public static let size = 10
    /// Les quatre diagonales.
    public static let directions: [(Int, Int)] = [(-1, -1), (-1, 1), (1, -1), (1, 1)]

    private var squares: [DraughtsPiece?]

    public init() {
        squares = Array(repeating: nil, count: Self.size * Self.size)
    }

    /// Position de départ : quatre rangées de chaque côté.
    public static func initial() -> DraughtsBoard {
        var board = DraughtsBoard()
        for row in 0..<size {
            for col in 0..<size {
                let square = Square(row, col)
                guard square.isPlayable else { continue }
                if row < 4 {
                    board[square] = DraughtsPiece(color: .black)
                } else if row >= size - 4 {
                    board[square] = DraughtsPiece(color: .white)
                }
            }
        }
        return board
    }

    public subscript(square: Square) -> DraughtsPiece? {
        get {
            guard square.isOnBoard else { return nil }
            return squares[square.row * Self.size + square.col]
        }
        set {
            guard square.isOnBoard else { return }
            squares[square.row * Self.size + square.col] = newValue
        }
    }

    public func isEmpty(_ square: Square) -> Bool {
        square.isOnBoard && self[square] == nil
    }

    public func pieces(of color: DraughtsColor) -> [Square] {
        var result: [Square] = []
        for row in 0..<Self.size {
            for col in 0..<Self.size {
                let square = Square(row, col)
                if self[square]?.color == color { result.append(square) }
            }
        }
        return result
    }

    public func count(of color: DraughtsColor) -> Int { pieces(of: color).count }
}
