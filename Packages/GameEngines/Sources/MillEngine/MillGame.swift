public enum MillState: Sendable, Equatable {
    /// Phase de pose : le joueur place un pion depuis sa réserve.
    case awaitingPlacement(MillPlayer)
    /// Phase de déplacement, ou de vol si le joueur n'a plus que trois pions.
    case awaitingMove(MillPlayer)
    /// Un moulin vient d'être formé : ce joueur retire un pion adverse.
    case awaitingRemoval(MillPlayer)
    case victory(MillPlayer)
    case draw

    public var activePlayer: MillPlayer? {
        switch self {
        case .awaitingPlacement(let p), .awaitingMove(let p), .awaitingRemoval(let p), .victory(let p): p
        case .draw: nil
        }
    }
}

public enum MillError: Error, Equatable, Sendable {
    case wrongState
    case notYourTurn(expected: MillPlayer)
    case pointOutOfRange
    case pointOccupied
    case pointEmpty
    case notYourPiece
    case notAdjacent
    /// Un pion pris dans un moulin est protégé, sauf si tous le sont.
    case pieceProtectedByMill
    case noPieceToRemove
}

/// Moteur de règles du jeu du moulin. Swift pur, testable sans interface.
public struct MillGame: Sendable, Equatable {
    public private(set) var points: [MillPlayer?]
    public private(set) var state: MillState
    public private(set) var menInHand: [MillPlayer: Int]
    /// Coups consécutifs sans moulin ni prise. Au-delà du seuil, partie nulle.
    public private(set) var idleMoves: Int

    public static let idleMoveLimit = 50

    public init(startingPlayer: MillPlayer = .white) {
        self.points = Array(repeating: nil, count: MillBoard.pointCount)
        self.state = .awaitingPlacement(startingPlayer)
        self.menInHand = [.white: MillBoard.menPerPlayer, .black: MillBoard.menPerPlayer]
        self.idleMoves = 0
    }

    // MARK: - Lecture

    public func menOnBoard(_ player: MillPlayer) -> Int {
        points.lazy.filter { $0 == player }.count
    }

    public func inHand(_ player: MillPlayer) -> Int { menInHand[player] ?? 0 }

    /// Total restant : réserve plus plateau. Sous trois, le joueur a perdu.
    public func remainingMen(_ player: MillPlayer) -> Int {
        inHand(player) + menOnBoard(player)
    }

    /// Un joueur réduit à trois pions peut sauter n'importe où.
    public func canFly(_ player: MillPlayer) -> Bool {
        inHand(player) == 0 && menOnBoard(player) == 3
    }

    public func isInMill(_ point: Int) -> Bool {
        guard let owner = points[safe: point] ?? nil else { return false }
        return MillBoard.millsThrough[point].contains { mill in
            mill.allSatisfy { points[$0] == owner }
        }
    }

    /// Destinations légales depuis une intersection, sans tenir compte du tour.
    public func destinations(from point: Int) -> [Int] {
        guard let owner = points[safe: point] ?? nil else { return [] }
        if canFly(owner) {
            return (0..<MillBoard.pointCount).filter { points[$0] == nil }
        }
        return MillBoard.adjacency[point].filter { points[$0] == nil }
    }

    public func hasLegalMove(_ player: MillPlayer) -> Bool {
        if inHand(player) > 0 { return true }
        return (0..<MillBoard.pointCount).contains { point in
            points[point] == player && !destinations(from: point).isEmpty
        }
    }

    /// Pions adverses qu'il est permis de retirer.
    public func removablePieces(for player: MillPlayer) -> [Int] {
        let target = player.opponent
        let owned = (0..<MillBoard.pointCount).filter { points[$0] == target }
        let unprotected = owned.filter { !isInMill($0) }
        // Si tous les pions adverses sont dans des moulins, ils redeviennent prenables.
        return unprotected.isEmpty ? owned : unprotected
    }

    // MARK: - Coups

    public mutating func place(at point: Int, by player: MillPlayer) throws {
        guard case .awaitingPlacement(let active) = state else { throw MillError.wrongState }
        guard active == player else { throw MillError.notYourTurn(expected: active) }
        guard (0..<MillBoard.pointCount).contains(point) else { throw MillError.pointOutOfRange }
        guard points[point] == nil else { throw MillError.pointOccupied }

        points[point] = player
        menInHand[player] = inHand(player) - 1

        resolve(after: point, by: player)
    }

    public mutating func move(from origin: Int, to destination: Int, by player: MillPlayer) throws {
        guard case .awaitingMove(let active) = state else { throw MillError.wrongState }
        guard active == player else { throw MillError.notYourTurn(expected: active) }
        guard (0..<MillBoard.pointCount).contains(origin),
              (0..<MillBoard.pointCount).contains(destination) else { throw MillError.pointOutOfRange }
        guard let owner = points[origin] else { throw MillError.pointEmpty }
        guard owner == player else { throw MillError.notYourPiece }
        guard points[destination] == nil else { throw MillError.pointOccupied }
        guard destinations(from: origin).contains(destination) else { throw MillError.notAdjacent }

        points[origin] = nil
        points[destination] = player

        resolve(after: destination, by: player)
    }

    public mutating func remove(at point: Int, by player: MillPlayer) throws {
        guard case .awaitingRemoval(let active) = state else { throw MillError.wrongState }
        guard active == player else { throw MillError.notYourTurn(expected: active) }
        guard (0..<MillBoard.pointCount).contains(point) else { throw MillError.pointOutOfRange }
        guard points[point] == player.opponent else { throw MillError.notYourPiece }

        let allowed = removablePieces(for: player)
        guard allowed.contains(point) else { throw MillError.pieceProtectedByMill }

        points[point] = nil
        idleMoves = 0
        advanceTurn(to: player.opponent)
    }

    // MARK: - Enchaînement

    private mutating func resolve(after point: Int, by player: MillPlayer) {
        if isInMill(point), !removablePieces(for: player).isEmpty {
            idleMoves = 0
            state = .awaitingRemoval(player)
        } else {
            idleMoves += 1
            advanceTurn(to: player.opponent)
        }
    }

    private mutating func advanceTurn(to next: MillPlayer) {
        // Défaite par attrition : moins de trois pions, réserve comprise.
        if remainingMen(next) < 3 {
            state = .victory(next.opponent)
            return
        }
        if idleMoves >= Self.idleMoveLimit {
            state = .draw
            return
        }
        if inHand(next) > 0 {
            state = .awaitingPlacement(next)
            return
        }
        // Défaite par blocage : plus aucun coup légal.
        guard hasLegalMove(next) else {
            state = .victory(next.opponent)
            return
        }
        state = .awaitingMove(next)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
