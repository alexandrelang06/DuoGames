public enum Player: String, Sendable, Hashable, CaseIterable {
    case a
    case b

    public var opponent: Player { self == .a ? .b : .a }
    public var localizationKey: String { "player.\(rawValue)" }
}

/// États de la partie.
///
/// `handover` matérialise le carton de confidentialité du plan B (FOLDABLE.md, Q1) : entre deux
/// phases de placement, l'écran masque tout le temps que les joueurs échangent l'appareil du regard.
/// Le modéliser ici plutôt que dans la vue le rend testable.
public enum GamePhase: Sendable, Equatable {
    case placement(Player)
    case handover(to: Player)
    case firing(Player)
    case victory(Player)

    public var activePlayer: Player? {
        switch self {
        case .placement(let player), .firing(let player), .victory(let player): player
        case .handover(let player): player
        }
    }

    public var isPrivacyScreenVisible: Bool {
        if case .handover = self { return true }
        return false
    }
}

public enum GameError: Error, Equatable, Sendable {
    case wrongPhase
    case notYourTurn(expected: Player)
    case placement(PlacementError)
}

/// Moteur de règles de la bataille navale. Swift pur, aucune dépendance UI (PRD §6.3).
public struct BattleshipGame: Sendable, Equatable {
    public private(set) var phase: GamePhase
    public private(set) var boards: [Player: Board]
    /// Le joueur qui a placé sa flotte en premier ouvre la phase de tir.
    public let startingPlayer: Player
    /// Historique des tirs, pour rejouer une partie ou animer un récapitulatif.
    public private(set) var log: [ShotRecord]

    public struct ShotRecord: Sendable, Equatable {
        public let shooter: Player
        public let coordinate: Coordinate
        public let outcome: ShotOutcome
    }

    public init(boardSize: Int = Board.defaultSize, startingPlayer: Player = .a) {
        self.startingPlayer = startingPlayer
        self.phase = .placement(startingPlayer)
        self.boards = [.a: Board(size: boardSize), .b: Board(size: boardSize)]
        self.log = []
    }

    public func board(for player: Player) -> Board {
        boards[player] ?? Board()
    }

    // MARK: - Placement

    public mutating func place(_ placement: ShipPlacement, for player: Player) throws {
        guard case .placement(let active) = phase else { throw GameError.wrongPhase }
        guard active == player else { throw GameError.notYourTurn(expected: active) }

        var board = board(for: player)
        do {
            try board.place(placement)
        } catch let error as PlacementError {
            throw GameError.placement(error)
        }
        boards[player] = board
    }

    @discardableResult
    public mutating func removeShip(_ kind: ShipKind, for player: Player) -> Bool {
        guard case .placement(let active) = phase, active == player else { return false }
        var board = board(for: player)
        let removed = board.remove(kind)
        boards[player] = board
        return removed
    }

    /// Valide la flotte du joueur actif et fait avancer la partie.
    ///
    /// Premier joueur : on passe par le carton de confidentialité avant que l'adversaire ne place.
    /// Second joueur : la phase de tir commence.
    public mutating func confirmFleet(for player: Player) throws {
        guard case .placement(let active) = phase else { throw GameError.wrongPhase }
        guard active == player else { throw GameError.notYourTurn(expected: active) }

        let playerBoard = board(for: player)
        guard playerBoard.isFleetComplete else {
            throw GameError.placement(.fleetIncomplete(missing: playerBoard.missingShips))
        }

        if board(for: player.opponent).isFleetComplete {
            phase = .firing(startingPlayer)
        } else {
            phase = .handover(to: player.opponent)
        }
    }

    /// L'appareil a changé de mains, on peut révéler la grille au joueur suivant.
    public mutating func acknowledgeHandover() throws {
        guard case .handover(let next) = phase else { throw GameError.wrongPhase }
        phase = .placement(next)
    }

    // MARK: - Tir

    /// Le joueur actif tire sur la grille adverse.
    ///
    /// Un tir touché ne rejoue pas : le tour alterne systématiquement, conformément au PRD §5.1
    /// qui décrit un tir au tour par tour sans mention de rejeu.
    @discardableResult
    public mutating func fire(at coordinate: Coordinate) throws -> ShotOutcome {
        guard case .firing(let shooter) = phase else { throw GameError.wrongPhase }

        var targetBoard = board(for: shooter.opponent)
        let outcome = targetBoard.receiveShot(at: coordinate)
        boards[shooter.opponent] = targetBoard

        guard outcome.didConsumeTurn else { return outcome }

        log.append(ShotRecord(shooter: shooter, coordinate: coordinate, outcome: outcome))

        if targetBoard.isFleetDestroyed {
            phase = .victory(shooter)
        } else {
            phase = .firing(shooter.opponent)
        }
        return outcome
    }
}
