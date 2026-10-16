/// Point d'entrée unique du retour sensoriel : un événement, un son **et** un pattern haptique.
///
/// Les vues n'appellent que `Feedback.play`. Le moteur émet une clé, jamais un fichier
/// (DESIGN.md §5, PRD §8.6).
@MainActor
enum Feedback {
    /// Toutes les clés connues, pour le préchargement au lancement.
    static let allKeys: [String] = [
        "game.select", "game.move", "game.place", "game.capture", "game.rejected", "game.victory",
        "airhockey.bounce", "airhockey.goal", "airhockey.relaunch", "airhockey.victory",
        "tron.turn", "tron.crash", "tron.victory",
    ]

    static func play(_ eventKey: String) {
        SoundPlayer.shared.play(eventKey)
        Haptics.play(eventKey)
    }

    static func preloadAll() {
        SoundPlayer.shared.preload(allKeys)
    }
}
