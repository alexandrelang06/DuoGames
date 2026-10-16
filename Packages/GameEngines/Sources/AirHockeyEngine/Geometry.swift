/// Fondations géométriques de l'air hockey.
///
/// La simulation physique complète relève de la Session 3 (PRD §11.3). Ce fichier ne pose que
/// les types valeur partagés, afin que la cible compile et que la géométrie du terrain — notamment
/// la gouttière de sécurité autour du pli — soit définie à un seul endroit.
public struct Vector2D: Sendable, Hashable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = Vector2D(x: 0, y: 0)

    public static func + (a: Vector2D, b: Vector2D) -> Vector2D {
        Vector2D(x: a.x + b.x, y: a.y + b.y)
    }

    public static func * (v: Vector2D, scalar: Double) -> Vector2D {
        Vector2D(x: v.x * scalar, y: v.y * scalar)
    }

    public var magnitude: Double { (x * x + y * y).squareRoot() }
}

public enum TableGeometry {
    /// Demi-largeur de la zone neutre centrée sur le pli, dans laquelle aucun élément de jeu
    /// critique ne doit s'immobiliser (PRD §5.2).
    public static let foldGutter: Double = 24

    /// Un palet immobilisé dans la gouttière devient invisible : le moteur devra le relancer.
    public static func isInFoldGutter(_ position: Vector2D, tableMidY: Double) -> Bool {
        abs(position.y - tableMidY) < foldGutter
    }
}
