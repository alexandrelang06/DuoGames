import Foundation

/// Sévérité d'un événement remonté.
public enum DiagnosticSeverity: String, Sendable, Hashable, Comparable, CaseIterable {
    case info
    case warning
    case error
    case crash

    private var rank: Int {
        switch self {
        case .info: 0
        case .warning: 1
        case .error: 2
        case .crash: 3
        }
    }

    public static func < (lhs: DiagnosticSeverity, rhs: DiagnosticSeverity) -> Bool {
        lhs.rank < rhs.rank
    }
}

public struct DiagnosticEvent: Sendable, Hashable, Identifiable {
    public let id: UUID
    public let date: Date
    public let severity: DiagnosticSeverity
    /// Catégorie technique : "posture", "battleship", "storekit"…
    public let category: String
    /// Message **sans donnée personnelle**. Voir MONITORING.md.
    public let message: String

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        severity: DiagnosticSeverity,
        category: String,
        message: String
    ) {
        self.id = id
        self.date = date
        self.severity = severity
        self.category = category
        self.message = message
    }
}

/// Tampon circulaire local des incidents.
///
/// Borné par construction : un jeu hors ligne ne doit jamais laisser un journal grossir
/// indéfiniment sur l'appareil du joueur. Rien n'est envoyé nulle part (PRD §4).
public struct DiagnosticLog: Sendable, Equatable {
    public private(set) var events: [DiagnosticEvent]
    public let capacity: Int

    public init(capacity: Int = 50) {
        precondition(capacity > 0, "capacité positive requise")
        self.capacity = capacity
        self.events = []
    }

    public mutating func record(_ event: DiagnosticEvent) {
        events.append(event)
        if events.count > capacity {
            events.removeFirst(events.count - capacity)
        }
    }

    public func filtered(minimum severity: DiagnosticSeverity) -> [DiagnosticEvent] {
        events.filter { $0.severity >= severity }
    }

    /// Le plus grave d'abord, puis le plus récent. Ordre d'affichage de l'écran de diagnostic.
    public var sortedByPriority: [DiagnosticEvent] {
        events.sorted {
            $0.severity == $1.severity ? $0.date > $1.date : $0.severity > $1.severity
        }
    }

    public mutating func clear() { events.removeAll() }

    public var hasBlockingEvents: Bool {
        events.contains { $0.severity >= .error }
    }
}
