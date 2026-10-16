import AVFoundation
import Diagnostics

/// Lecteur de sons centralisé (DESIGN.md §5). Un son nommé par événement, rien d'autre.
///
/// Les fichiers sont préchargés au premier usage et joués sur des instances dédiées,
/// pour que deux rebonds rapprochés ne se coupent pas l'un l'autre.
@MainActor
final class SoundPlayer {
    static let shared = SoundPlayer()

    private var players: [String: [AVAudioPlayer]] = [:]
    private static let voicesPerSound = 3

    private init() {
        // Catégorie ambiante : on respecte le bouton silence et on ne coupe pas la musique du joueur.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "settings.sound") as? Bool ?? true
    }

    /// Nom de fichier dérivé de la clé : `airhockey.goal` → `airhockey_goal.caf`.
    private static func fileName(for eventKey: String) -> String {
        eventKey.replacingOccurrences(of: ".", with: "_")
    }

    func preload(_ eventKeys: [String]) {
        for key in eventKeys where players[key] == nil {
            guard let url = Bundle.main.url(forResource: Self.fileName(for: key), withExtension: "caf") else {
                DiagnosticsCenter.shared.record(.warning, category: "audio", "Son manquant : \(key)")
                continue
            }
            players[key] = (0..<Self.voicesPerSound).compactMap { _ in
                let player = try? AVAudioPlayer(contentsOf: url)
                player?.prepareToPlay()
                return player
            }
        }
    }

    func play(_ eventKey: String, volume: Float = 1) {
        guard isEnabled else { return }
        if players[eventKey] == nil { preload([eventKey]) }
        guard let voices = players[eventKey], !voices.isEmpty else { return }
        // Première voix libre, sinon on vole la plus ancienne.
        let player = voices.first { !$0.isPlaying } ?? voices[0]
        player.currentTime = 0
        player.volume = volume
        player.play()
    }
}
