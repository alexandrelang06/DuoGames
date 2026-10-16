public struct DraughtsMove: Sendable, Hashable {
    public let origin: Square
    /// Cases d'atterrissage successives. La dernière est la destination finale.
    public let path: [Square]
    /// Pions capturés, retirés seulement à la fin du coup (règle du coup turc).
    public let captured: [Square]
    public let promotes: Bool

    public var destination: Square { path.last ?? origin }
    public var isCapture: Bool { !captured.isEmpty }

    public init(origin: Square, path: [Square], captured: [Square] = [], promotes: Bool = false) {
        self.origin = origin
        self.path = path
        self.captured = captured
        self.promotes = promotes
    }
}

public enum DraughtsMoveGenerator {

    /// Coups légaux du camp au trait.
    ///
    /// La prise est obligatoire, et parmi les prises il faut choisir celle qui capture
    /// le plus de pions — c'est la règle de la majorité du jeu international.
    public static func legalMoves(for color: DraughtsColor, on board: DraughtsBoard) -> [DraughtsMove] {
        let captures = allCaptures(for: color, on: board)
        if !captures.isEmpty {
            let best = captures.map(\.captured.count).max() ?? 0
            return captures.filter { $0.captured.count == best }
        }
        return quietMoves(for: color, on: board)
    }

    /// Toutes les rafles possibles, sans filtrage par majorité.
    public static func allCaptures(for color: DraughtsColor, on board: DraughtsBoard) -> [DraughtsMove] {
        board.pieces(of: color).flatMap { captures(from: $0, on: board) }
    }

    public static func captures(from origin: Square, on board: DraughtsBoard) -> [DraughtsMove] {
        guard let piece = board[origin] else { return [] }

        // Le pion quitte sa case : elle ne bloque plus la rafle.
        var working = board
        working[origin] = nil

        var results: [(path: [Square], captured: [Square])] = []
        explore(piece: piece, current: origin, board: working, captured: [], path: [], results: &results)

        return results.map { result in
            let destination = result.path.last ?? origin
            let promotes = !piece.isKing && destination.row == piece.color.promotionRow
            return DraughtsMove(origin: origin, path: result.path,
                                captured: result.captured, promotes: promotes)
        }
    }

    /// Parcours récursif des rafles. Tant qu'une prise reste possible, il faut la jouer.
    private static func explore(
        piece: DraughtsPiece,
        current: Square,
        board: DraughtsBoard,
        captured: [Square],
        path: [Square],
        results: inout [(path: [Square], captured: [Square])]
    ) {
        var canContinue = false

        for (dRow, dCol) in DraughtsBoard.directions {
            if piece.isKing {
                // Dame volante : elle glisse jusqu'au premier pion rencontré.
                var scan = current.offset(dRow, dCol)
                while scan.isOnBoard, board[scan] == nil {
                    scan = scan.offset(dRow, dCol)
                }
                guard scan.isOnBoard,
                      let target = board[scan],
                      target.color != piece.color,
                      !captured.contains(scan) else { continue }

                // Elle peut se poser sur n'importe quelle case libre au-delà.
                var landing = scan.offset(dRow, dCol)
                while landing.isOnBoard, board[landing] == nil {
                    canContinue = true
                    explore(piece: piece, current: landing, board: board,
                            captured: captured + [scan], path: path + [landing], results: &results)
                    landing = landing.offset(dRow, dCol)
                }
            } else {
                // Le pion prend dans les quatre directions, y compris en arrière.
                let targetSquare = current.offset(dRow, dCol)
                let landing = current.offset(dRow * 2, dCol * 2)
                guard landing.isOnBoard, board[landing] == nil,
                      let target = board[targetSquare],
                      target.color != piece.color,
                      !captured.contains(targetSquare) else { continue }

                canContinue = true
                explore(piece: piece, current: landing, board: board,
                        captured: captured + [targetSquare], path: path + [landing], results: &results)
            }
        }

        // Une rafle ne s'arrête que lorsqu'aucune prise n'est plus possible.
        if !canContinue, !captured.isEmpty {
            results.append((path, captured))
        }
    }

    public static func quietMoves(for color: DraughtsColor, on board: DraughtsBoard) -> [DraughtsMove] {
        var moves: [DraughtsMove] = []

        for origin in board.pieces(of: color) {
            guard let piece = board[origin] else { continue }

            if piece.isKing {
                for (dRow, dCol) in DraughtsBoard.directions {
                    var destination = origin.offset(dRow, dCol)
                    while destination.isOnBoard, board[destination] == nil {
                        moves.append(DraughtsMove(origin: origin, path: [destination]))
                        destination = destination.offset(dRow, dCol)
                    }
                }
            } else {
                // Le pion n'avance que vers le camp adverse.
                for dCol in [-1, 1] {
                    let destination = origin.offset(color.forwardStep, dCol)
                    guard destination.isOnBoard, board[destination] == nil else { continue }
                    let promotes = destination.row == color.promotionRow
                    moves.append(DraughtsMove(origin: origin, path: [destination], promotes: promotes))
                }
            }
        }
        return moves
    }
}
