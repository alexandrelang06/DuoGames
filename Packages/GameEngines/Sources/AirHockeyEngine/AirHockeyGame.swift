import Foundation

public enum AirHockeyPlayer: String, Sendable, Hashable, CaseIterable {
    /// Occupe la moitié basse de l'écran (y > midY), défend le but y = hauteur.
    case near
    /// Occupe la moitié haute (y < midY), défend le but y = 0.
    case far

    public var opponent: AirHockeyPlayer { self == .near ? .far : .near }
    public var localizationKey: String { "airhockey.player.\(rawValue)" }
}

public struct TableSpec: Sendable, Hashable {
    public let width: Double
    public let height: Double
    /// Largeur de la bouche des buts, centrée sur l'axe long.
    public let goalWidth: Double
    public let puckRadius: Double
    public let malletRadius: Double

    public init(
        width: Double = 400,
        height: Double = 700,
        goalWidth: Double = 160,
        puckRadius: Double = 14,
        malletRadius: Double = 26
    ) {
        self.width = width
        self.height = height
        self.goalWidth = goalWidth
        self.puckRadius = puckRadius
        self.malletRadius = malletRadius
    }

    public var midY: Double { height / 2 }
    public var goalMinX: Double { (width - goalWidth) / 2 }
    public var goalMaxX: Double { (width + goalWidth) / 2 }

    public func isWithinGoalMouth(x: Double) -> Bool {
        x >= goalMinX && x <= goalMaxX
    }
}

public enum AirHockeyEvent: Sendable, Equatable {
    case bounce
    case goal(AirHockeyPlayer)
    /// Le palet s'est immobilisé sur le pli : on le relance pour qu'il reste visible.
    case relaunchedFromFold
    case matchOver(winner: AirHockeyPlayer)

    public var eventKey: String {
        switch self {
        case .bounce: "airhockey.bounce"
        case .goal: "airhockey.goal"
        case .relaunchedFromFold: "airhockey.relaunch"
        case .matchOver: "airhockey.victory"
        }
    }
}

public struct AirHockeyGame: Sendable {
    public let spec: TableSpec
    public let goalsToWin: Int

    public private(set) var puckPosition: Vector2D
    public private(set) var puckVelocity: Vector2D
    public private(set) var mallets: [AirHockeyPlayer: Vector2D]
    /// Position des maillets au tick précédent, pour estimer leur vitesse.
    private var previousMallets: [AirHockeyPlayer: Vector2D]
    /// Vitesse des maillets sur le tick courant, calculée en début de `tick`.
    private var malletVelocities: [AirHockeyPlayer: Vector2D] = [:]
    public private(set) var scores: [AirHockeyPlayer: Int]
    public private(set) var isPaused: Bool
    public private(set) var winner: AirHockeyPlayer?

    /// Perte de vitesse par seconde. Le palet glisse, il ne roule pas.
    public static let friction: Double = 0.12
    /// Restitution des bandes. En dessous de 1, le palet perd un peu à chaque rebond.
    public static let wallRestitution: Double = 0.92
    public static let maxSpeed: Double = 1_150
    /// En dessous, le palet est considéré immobile.
    public static let stallSpeed: Double = 12
    /// Part de la vitesse du maillet transmise au palet à l'impact.
    public static let malletTransfer: Double = 0.7
    /// Vitesse d'engagement.
    public static let serveSpeed: Double = 240

    public init(spec: TableSpec = TableSpec(), goalsToWin: Int = 7, servingTo: AirHockeyPlayer = .near) {
        self.spec = spec
        self.goalsToWin = goalsToWin
        self.puckPosition = Vector2D(x: spec.width / 2, y: spec.midY)
        self.puckVelocity = .zero
        let startMallets = [
            AirHockeyPlayer.near: Vector2D(x: spec.width / 2, y: spec.height * 0.85),
            AirHockeyPlayer.far: Vector2D(x: spec.width / 2, y: spec.height * 0.15),
        ]
        self.mallets = startMallets
        self.previousMallets = startMallets
        self.scores = [.near: 0, .far: 0]
        self.isPaused = false
        self.winner = nil
        serve(to: servingTo)
    }

    public var isOver: Bool { winner != nil }
    public func score(_ player: AirHockeyPlayer) -> Int { scores[player] ?? 0 }
    public func mallet(_ player: AirHockeyPlayer) -> Vector2D { mallets[player]! }

    // MARK: - Maillets

    /// Chaque joueur est confiné à sa moitié : le maillet ne franchit jamais le pli.
    public func clampedMalletPosition(_ raw: Vector2D, for player: AirHockeyPlayer) -> Vector2D {
        let radius = spec.malletRadius
        let x = min(max(raw.x, radius), spec.width - radius)
        let y: Double = switch player {
        case .near: min(max(raw.y, spec.midY + radius), spec.height - radius)
        case .far: min(max(raw.y, radius), spec.midY - radius)
        }
        return Vector2D(x: x, y: y)
    }

    @discardableResult
    public mutating func moveMallet(_ player: AirHockeyPlayer, to raw: Vector2D) -> Vector2D {
        let clamped = clampedMalletPosition(raw, for: player)
        mallets[player] = clamped
        return clamped
    }

    public mutating func togglePause() { isPaused.toggle() }

    // MARK: - Simulation

    /// Avance la simulation d'un pas de temps fixe et renvoie les événements du pas.
    @discardableResult
    public mutating func tick(_ dt: Double) -> [AirHockeyEvent] {
        guard !isPaused, !isOver, dt > 0 else { return [] }
        var events: [AirHockeyEvent] = []

        // Vitesse des maillets sur ce pas : déplacement depuis le tick précédent.
        for player in AirHockeyPlayer.allCases {
            let delta = mallet(player) - (previousMallets[player] ?? mallet(player))
            malletVelocities[player] = delta * (1 / dt)
            previousMallets[player] = mallet(player)
        }

        // Frottement exponentiel : indépendant du pas de temps.
        let decay = pow(1 - Self.friction, dt)
        puckVelocity = puckVelocity * decay

        var next = puckPosition + puckVelocity * dt

        // Bandes latérales.
        let radius = spec.puckRadius
        if next.x < radius {
            next.x = radius
            puckVelocity.x = -puckVelocity.x * Self.wallRestitution
            events.append(.bounce)
        } else if next.x > spec.width - radius {
            next.x = spec.width - radius
            puckVelocity.x = -puckVelocity.x * Self.wallRestitution
            events.append(.bounce)
        }

        // Fonds de table : but ou rebond.
        if next.y < radius {
            if spec.isWithinGoalMouth(x: next.x) {
                puckPosition = next
                events.append(contentsOf: registerGoal(by: .near))
                return events
            }
            next.y = radius
            puckVelocity.y = -puckVelocity.y * Self.wallRestitution
            events.append(.bounce)
        } else if next.y > spec.height - radius {
            if spec.isWithinGoalMouth(x: next.x) {
                puckPosition = next
                events.append(contentsOf: registerGoal(by: .far))
                return events
            }
            next.y = spec.height - radius
            puckVelocity.y = -puckVelocity.y * Self.wallRestitution
            events.append(.bounce)
        }

        puckPosition = next

        for player in AirHockeyPlayer.allCases {
            if resolveMalletCollision(with: player) { events.append(.bounce) }
        }

        clampSpeed()

        // Le palet ne doit jamais s'arrêter sur le pli : il y deviendrait invisible.
        if puckVelocity.magnitude < Self.stallSpeed,
           TableGeometry.isInFoldGutter(puckPosition, tableMidY: spec.midY) {
            relaunchFromFold()
            events.append(.relaunchedFromFold)
        }

        return events
    }

    private mutating func resolveMalletCollision(with player: AirHockeyPlayer) -> Bool {
        let mallet = self.mallet(player)
        let delta = Vector2D(x: puckPosition.x - mallet.x, y: puckPosition.y - mallet.y)
        let distance = delta.magnitude
        let contact = spec.puckRadius + spec.malletRadius
        guard distance < contact, distance > 0.0001 else { return false }

        let normal = Vector2D(x: delta.x / distance, y: delta.y / distance)

        // On dégage le palet du maillet pour éviter qu'il s'y encastre.
        puckPosition = mallet + normal * contact

        // Réflexion de la vitesse du palet autour de la normale.
        let alongNormal = puckVelocity.x * normal.x + puckVelocity.y * normal.y
        if alongNormal < 0 {
            puckVelocity = puckVelocity + normal * (-2 * alongNormal)
        }
        // Transfert de la vitesse du maillet, mais seulement s'il pousse vers le palet.
        let malletVelocity = malletVelocities[player] ?? .zero
        let malletAlongNormal = malletVelocity.x * normal.x + malletVelocity.y * normal.y
        if malletAlongNormal > 0 {
            puckVelocity = puckVelocity + normal * (malletAlongNormal * Self.malletTransfer)
        }
        return true
    }

    private mutating func clampSpeed() {
        let speed = puckVelocity.magnitude
        guard speed > Self.maxSpeed else { return }
        puckVelocity = puckVelocity * (Self.maxSpeed / speed)
    }

    private mutating func relaunchFromFold() {
        // Poussée vers le camp de personne en particulier : on garde le hasard hors du score.
        let direction: Double = puckPosition.x < spec.width / 2 ? 1 : -1
        puckVelocity = Vector2D(x: direction * 180, y: 0)
    }

    private mutating func registerGoal(by scorer: AirHockeyPlayer) -> [AirHockeyEvent] {
        scores[scorer] = score(scorer) + 1
        var events: [AirHockeyEvent] = [.goal(scorer)]

        if score(scorer) >= goalsToWin {
            winner = scorer
            puckVelocity = .zero
            events.append(.matchOver(winner: scorer))
            return events
        }
        // Engagement alterné : celui qui encaisse remet en jeu.
        serve(to: scorer.opponent)
        return events
    }

    /// Lance le palet depuis une position et une vitesse données.
    public mutating func launch(from position: Vector2D, velocity: Vector2D) {
        puckPosition = position
        puckVelocity = velocity
    }

    /// Remet le palet **immobile** dans la moitié du joueur qui reçoit, centré en largeur.
    ///
    /// Après un but, c'est le joueur qui l'a encaissé qui reçoit : le palet l'attend dans son
    /// camp, figé, jusqu'à ce qu'il le frappe. Placé à l'écart du pli pour rester visible et ne pas
    /// déclencher la relance de gouttière.
    public mutating func serve(to player: AirHockeyPlayer) {
        let y = player == .near ? spec.height * 0.72 : spec.height * 0.28
        puckPosition = Vector2D(x: spec.width / 2, y: y)
        puckVelocity = .zero
    }
}

public extension Vector2D {
    static func - (a: Vector2D, b: Vector2D) -> Vector2D {
        Vector2D(x: a.x - b.x, y: a.y - b.y)
    }
}
