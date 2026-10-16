import SwiftUI

/// Illustration animée de l'onboarding, une par étape. Dessinée en SwiftUI, sans image externe.
///
/// L'étape 1 montre un téléphone qui s'ouvre et se pose à plat : c'est l'invitation au mode Duo.
/// L'étape 2 montre deux joueurs face à face autour de l'appareil. L'étape 3, la manette du jeu.
/// Reduce Motion fige sur une image représentative.
struct OnboardingAnimation: View {
    let step: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                frame(phase: 0.6)
            } else {
                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    frame(phase: (t.truncatingRemainder(dividingBy: loop)) / loop)
                }
            }
        }
        .frame(height: 180)
        .accessibilityHidden(true)
    }

    private var loop: Double { step == 0 ? 3.5 : 3 }

    @ViewBuilder
    private func frame(phase: Double) -> some View {
        switch step {
        case 0: UnfoldingPhone(phase: phase)
        case 1: FacingPlayers(phase: phase)
        default: PlayPulse(phase: phase)
        }
    }
}

/// Un téléphone qui passe de plié à plat, en boucle : incite à ouvrir le Duo.
private struct UnfoldingPhone: View {
    let phase: Double

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let halfW: CGFloat = 52
            let halfH: CGFloat = 78

            // Angle d'ouverture : de ~50° (plié) à 180° (à plat), aller-retour doux.
            let p = phase < 0.5 ? phase * 2 : (1 - phase) * 2
            let eased = 0.5 - cos(p * .pi) / 2
            let openAngle = (50 + (180 - 50) * eased) * .pi / 180
            let tilt = openAngle / 2

            func panel(sign: CGFloat) -> Path {
                // Deux moitiés articulées autour de la charnière centrale (axe vertical).
                let dx = cos(.pi / 2 - tilt) * halfW * sign
                let dy = sin(.pi / 2 - tilt) * halfW
                var path = Path()
                let hinge1 = CGPoint(x: center.x, y: center.y - halfH / 2)
                let hinge2 = CGPoint(x: center.x, y: center.y + halfH / 2)
                let outer1 = CGPoint(x: center.x + dx, y: center.y - halfH / 2 - (sign > 0 ? 0 : 0) + dy - halfW * 0)
                _ = outer1
                let topOuter = CGPoint(x: center.x + dx, y: hinge1.y - (dy - halfW) * 0 )
                let botOuter = CGPoint(x: center.x + dx, y: hinge2.y)
                path.move(to: hinge1)
                path.addLine(to: topOuter)
                path.addLine(to: botOuter)
                path.addLine(to: hinge2)
                path.closeSubpath()
                return path
            }

            let left = panel(sign: -1)
            let right = panel(sign: 1)
            context.fill(left, with: .color(Theme.Umbrella.ink.opacity(0.85)))
            context.fill(right, with: .color(Theme.Umbrella.ink))

            // Écran lumineux qui s'agrandit à mesure que ça s'ouvre.
            let glow = 0.2 + 0.8 * eased
            context.fill(left, with: .color(Theme.Accent.airHockey.opacity(0.15 * glow)))
            context.fill(right, with: .color(Theme.Accent.tron.opacity(0.15 * glow)))

            // Charnière.
            var hinge = Path()
            hinge.move(to: CGPoint(x: center.x, y: center.y - halfH / 2))
            hinge.addLine(to: CGPoint(x: center.x, y: center.y + halfH / 2))
            context.stroke(hinge, with: .color(Theme.Umbrella.paper), lineWidth: 2)

            // Flèches d'ouverture quand c'est encore plié.
            if eased < 0.9 {
                let arrowAlpha = (0.9 - eased) / 0.9
                for dir in [-1.0, 1.0] {
                    var a = Path()
                    let x = center.x + CGFloat(dir) * 78
                    a.move(to: CGPoint(x: x, y: center.y - 8))
                    a.addLine(to: CGPoint(x: x + CGFloat(dir) * 8, y: center.y))
                    a.addLine(to: CGPoint(x: x, y: center.y + 8))
                    context.stroke(a, with: .color(Theme.Umbrella.inkSecondary.opacity(arrowAlpha)), lineWidth: 2.5)
                }
            }
        }
    }
}

/// Deux jetons de couleur face à face autour d'un appareil posé.
private struct FacingPlayers: View {
    let phase: Double

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            // Appareil à plat.
            let device = CGRect(x: center.x - 34, y: center.y - 52, width: 68, height: 104)
            context.fill(Path(roundedRect: device, cornerRadius: 10), with: .color(Theme.Umbrella.ink))
            var mid = Path()
            mid.move(to: CGPoint(x: device.minX, y: center.y))
            mid.addLine(to: CGPoint(x: device.maxX, y: center.y))
            context.stroke(mid, with: .color(Theme.Umbrella.paper.opacity(0.4)), style: .init(lineWidth: 1, dash: [4, 3]))

            // Deux joueurs qui « respirent » doucement de part et d'autre.
            let breathe = sin(phase * .pi * 2) * 4
            let top = CGPoint(x: center.x, y: device.minY - 34 - breathe)
            let bottom = CGPoint(x: center.x, y: device.maxY + 34 + breathe)
            for (p, color) in [(top, Theme.Accent.tron), (bottom, Theme.Accent.airHockey)] {
                context.fill(Path(ellipseIn: CGRect(x: p.x - 16, y: p.y - 16, width: 32, height: 32)),
                             with: .color(color))
            }
        }
    }
}

/// Une pastille qui pulse : « c'est parti ».
private struct PlayPulse: View {
    let phase: Double

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let pulse = 1 + sin(phase * .pi * 2) * 0.08
            let r: CGFloat = 42 * pulse
            context.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                         with: .color(Theme.Accent.airHockey))
            // Triangle « play ».
            var tri = Path()
            tri.move(to: CGPoint(x: center.x - 12, y: center.y - 18))
            tri.addLine(to: CGPoint(x: center.x + 20, y: center.y))
            tri.addLine(to: CGPoint(x: center.x - 12, y: center.y + 18))
            tri.closeSubpath()
            context.fill(tri, with: .color(Theme.Umbrella.paper))
        }
    }
}
