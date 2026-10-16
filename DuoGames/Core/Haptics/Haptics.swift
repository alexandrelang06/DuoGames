import UIKit

/// Patterns haptiques nommés par événement (DESIGN.md §5). Mêmes clés que le son.
@MainActor
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let notification = UINotificationFeedbackGenerator()

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "settings.haptics") as? Bool ?? true
    }

    static func play(_ eventKey: String) {
        guard isEnabled else { return }
        switch eventKey {
        case "game.select":
            light.impactOccurred(intensity: 0.5)
        case "game.move", "tron.turn":
            light.impactOccurred()
        case "game.place":
            rigid.impactOccurred()
        case "game.capture", "airhockey.bounce":
            medium.impactOccurred()
        case "game.rejected":
            notification.notificationOccurred(.warning)
        case "airhockey.goal":
            // Double impulsion (DESIGN.md §5).
            rigid.impactOccurred()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(90))
                rigid.impactOccurred()
            }
        case "tron.crash":
            notification.notificationOccurred(.error)
        case "game.victory", "airhockey.victory", "tron.victory":
            notification.notificationOccurred(.success)
        default:
            break
        }
    }
}
