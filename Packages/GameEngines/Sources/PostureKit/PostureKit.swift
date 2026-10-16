import Foundation

/// Abstraction totale des APIs pliables de l'iPhone Duo.
///
/// **Raison d'être** (FOLDABLE.md) : le SDK iOS 26.5 disponible aujourd'hui ne contient ni
/// `onHingeChange`, ni `ArrangementView`, ni `reservedRegion`. Aucune vue de l'app n'appelle
/// directement une API Duo : tout passe par `PostureProviding`. Le jour du portage vers le
/// SDK 27.1, la surface à corriger tient dans une seule implémentation.
///
/// Règle Apple non négociable, reprise ici : l'angle de charnière pilote les **effets**,
/// jamais le **layout**, qui reste du ressort des size classes et des régions réservées.

// MARK: - Poses

/// Les cinq poses système documentées par Apple.
public enum Pose: String, Sendable, Hashable, CaseIterable {
    case closed
    case portrait
    case landscape
    case seated
    case standing
    /// Appareil non pliable, ou pose indéterminée. Toujours géré (PRD §6.3).
    case unknown

    public var localizationKey: String { "pose.\(rawValue)" }
}

/// Postures de jeu utiles au produit, dérivées de la pose et de l'angle.
public enum GamePosture: Sendable, Hashable {
    /// Ouvert à plat sur la table : support des deux jeux.
    case flat
    /// Partiellement plié : convient au guidage, pas au jeu.
    case partiallyFolded
    /// Fermé ou inutilisable pour jouer à deux.
    case unsuitable
    /// Appareil non pliable. Mode dégradé, jouable (PRD §6.3).
    case nonFoldable
}

// MARK: - Seuils

/// Seuils angulaires, isolés ici parce qu'ils sont **non vérifiés** (FOLDABLE.md, Q2).
/// Aucun littéral d'angle ne doit apparaître ailleurs dans le code.
public enum HingeThresholds {
    /// Au-delà, l'appareil est considéré à plat.
    public static let flatMinimum: Double = 170
    /// En deçà, l'appareil est considéré fermé.
    public static let closedMaximum: Double = 15
    /// Tolérance avant de déclencher l'alerte anti-triche pendant le placement (PRD §5.1).
    public static let flatTolerance: Double = 20

    public static func posture(forAngle angle: Double?) -> GamePosture {
        guard let angle else { return .nonFoldable }
        if angle >= flatMinimum { return .flat }
        if angle <= closedMaximum { return .unsuitable }
        return .partiallyFolded
    }
}

// MARK: - Régions réservées

/// Zone à éviter : le pli lui-même, ou une occlusion caméra.
public struct ReservedRegion: Sendable, Hashable {
    public enum Kind: Sendable, Hashable {
        /// Le pli. Sépare l'écran en deux zones.
        case division
        /// Découpe matérielle (caméras).
        case occlusion
    }

    public let kind: Kind
    public let origin: (x: Double, y: Double)
    public let size: (width: Double, height: Double)

    public init(kind: Kind, x: Double, y: Double, width: Double, height: Double) {
        self.kind = kind
        self.origin = (x, y)
        self.size = (width, height)
    }

    public static func == (lhs: ReservedRegion, rhs: ReservedRegion) -> Bool {
        lhs.kind == rhs.kind && lhs.origin == rhs.origin && lhs.size == rhs.size
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(kind)
        hasher.combine(origin.x); hasher.combine(origin.y)
        hasher.combine(size.width); hasher.combine(size.height)
    }

    /// Marge de sécurité appliquée de part et d'autre du pli.
    ///
    /// Le PRD §5.2 fixait 24 pt pour l'air hockey ; FOLDABLE.md Q3 généralise à toute l'app,
    /// le comportement tactile réel près du pli n'étant pas documenté.
    public static let safetyGutter: Double = 24

    /// Région élargie de la marge de sécurité. C'est celle que le layout doit éviter.
    public var inflated: ReservedRegion {
        ReservedRegion(
            kind: kind,
            x: origin.x - Self.safetyGutter,
            y: origin.y - Self.safetyGutter,
            width: size.width + Self.safetyGutter * 2,
            height: size.height + Self.safetyGutter * 2
        )
    }
}

// MARK: - Fourniture de posture

public struct PostureSnapshot: Sendable, Hashable {
    public let pose: Pose
    /// `nil` sur appareil non pliable. Tout accès doit être gardé.
    public let hingeAngle: Double?
    public let reservedRegions: [ReservedRegion]

    public init(pose: Pose, hingeAngle: Double?, reservedRegions: [ReservedRegion] = []) {
        self.pose = pose
        self.hingeAngle = hingeAngle
        self.reservedRegions = reservedRegions
    }

    public var posture: GamePosture { HingeThresholds.posture(forAngle: hingeAngle) }

    public var isFoldable: Bool { hingeAngle != nil }

    /// Appareil classique : mode dégradé, mais parfaitement jouable grâce au plan B.
    public static let nonFoldable = PostureSnapshot(pose: .unknown, hingeAngle: nil)
}

public protocol PostureProviding: Sendable {
    var current: PostureSnapshot { get }
}

/// Implémentation utilisable dès aujourd'hui, sur SDK 26.5 et sur iPhone classique.
public struct SimulatedPostureProvider: PostureProviding {
    public let current: PostureSnapshot

    public init(_ snapshot: PostureSnapshot = .nonFoldable) {
        self.current = snapshot
    }

    /// Raccourci de test : simule un Duo ouvert à plat.
    public static let flatDuo = SimulatedPostureProvider(
        PostureSnapshot(pose: .landscape, hingeAngle: 180)
    )
}
