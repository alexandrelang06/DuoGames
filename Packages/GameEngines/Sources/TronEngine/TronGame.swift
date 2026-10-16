/// Duel de motos lumineuses. Temps réel, coups simultanés, arène symétrique —
/// aucun haut ni bas, donc parfaitement lisible en tête-bêche.

public enum TronRider: String, Sendable, Hashable, CaseIterable {
    case cyan
    case magenta

    public var opponent: TronRider { self == .cyan ? .magenta : .cyan }
    public var localizationKey: String { "tron.rider.\(rawValue)" }
}

public enum Direction: Sendable, Hashable, CaseIterable {
    case up, down, left, right

    public var delta: (dx: Int, dy: Int) {
        switch self {
        case .up: (0, -1)
        case .down: (0, 1)
        case .left: (-1, 0)
        case .right: (1, 0)
        }
    }

    public var opposite: Direction {
        switch self {
        case .up: .down
        case .down: .up
        case .left: .right
        case .right: .left
        }
    }
}

public struct GridPoint: Hashable, Sendable {
    public let x: Int
    public let y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    public func moved(_ direction: Direction) -> GridPoint {
        GridPoint(x: x + direction.delta.dx, y: y + direction.delta.dy)
    }
}

public enum TronOutcome: Sendable, Equatable {
    case running
    case victory(TronRider)
    /// Collision frontale ou double sortie : personne ne gagne.
    case draw
}

public struct TronGame: Sendable, Equatable {
    public let width: Int
    public let height: Int

    public private(set) var positions: [TronRider: GridPoint]
    public private(set) var headings: [TronRider: Direction]
    public private(set) var trails: [TronRider: Set<GridPoint>]
    public private(set) var outcome: TronOutcome
    public private(set) var tickCount: Int

    public init(width: Int = 40, height: Int = 30) {
        precondition(width >= 4 && height >= 4, "arène trop petite")
        self.width = width
        self.height = height

        // Chacun part de sa moitié et fonce vers l'autre à travers le pli.
        // La gouttière du pli reste vide au départ (FOLDABLE.md Q3).
        let cyanStart = GridPoint(x: width / 2, y: 3 * height / 4)
        let magentaStart = GridPoint(x: width / 2, y: height / 4)

        self.positions = [.cyan: cyanStart, .magenta: magentaStart]
        self.headings = [.cyan: .up, .magenta: .down]
        self.trails = [.cyan: [cyanStart], .magenta: [magentaStart]]
        self.outcome = .running
        self.tickCount = 0
    }

    // MARK: - Lecture

    public func position(of rider: TronRider) -> GridPoint { positions[rider]! }
    public func heading(of rider: TronRider) -> Direction { headings[rider]! }
    public func trail(of rider: TronRider) -> Set<GridPoint> { trails[rider]! }

    public func contains(_ point: GridPoint) -> Bool {
        (0..<width).contains(point.x) && (0..<height).contains(point.y)
    }

    public func isOccupied(_ point: GridPoint) -> Bool {
        trails.values.contains { $0.contains(point) }
    }

    public var isRunning: Bool { outcome == .running }

    // MARK: - Pilotage

    /// Change le cap. Le demi-tour est refusé : on ne rentre pas dans son propre sillage.
    @discardableResult
    public mutating func steer(_ rider: TronRider, _ direction: Direction) -> Bool {
        guard isRunning else { return false }
        guard direction != heading(of: rider).opposite else { return false }
        headings[rider] = direction
        return true
    }

    /// Avance les deux motos d'une case. Les deux avancent en même temps :
    /// une collision frontale tue les deux, pas seulement celui qui a bougé « en second ».
    public mutating func tick() {
        guard isRunning else { return }
        tickCount += 1

        let next = Dictionary(uniqueKeysWithValues: TronRider.allCases.map {
            ($0, position(of: $0).moved(heading(of: $0)))
        })

        var dead: Set<TronRider> = []
        for rider in TronRider.allCases {
            let destination = next[rider]!
            if !contains(destination) || isOccupied(destination) {
                dead.insert(rider)
            }
        }

        // Collision frontale : les deux visent la même case.
        if next[.cyan] == next[.magenta] {
            dead.formUnion(TronRider.allCases)
        }

        // Croisement : elles échangent leurs positions dans le même tick.
        if next[.cyan] == position(of: .magenta), next[.magenta] == position(of: .cyan) {
            dead.formUnion(TronRider.allCases)
        }

        guard dead.isEmpty else {
            outcome = dead.count == 2 ? .draw : .victory(dead.first!.opponent)
            return
        }

        for rider in TronRider.allCases {
            positions[rider] = next[rider]
            trails[rider]!.insert(next[rider]!)
        }
    }
}
