import Testing
@testable import AirHockeyEngine

@Suite("Géométrie du terrain")
struct GeometryTests {

    @Test("Le vecteur nul a une magnitude nulle")
    func zeroMagnitude() {
        #expect(Vector2D.zero.magnitude == 0)
    }

    @Test("La magnitude suit Pythagore")
    func magnitude() {
        #expect(Vector2D(x: 3, y: 4).magnitude == 5)
    }

    @Test("Un palet arrêté sur le pli est détecté comme invisible")
    func puckInFoldGutter() {
        // PRD §5.2 : le palet ne doit jamais devenir invisible dans la zone du pli.
        #expect(TableGeometry.isInFoldGutter(Vector2D(x: 100, y: 400), tableMidY: 400))
        #expect(TableGeometry.isInFoldGutter(Vector2D(x: 100, y: 410), tableMidY: 400))
        #expect(TableGeometry.isInFoldGutter(Vector2D(x: 100, y: 500), tableMidY: 400) == false)
    }
}
