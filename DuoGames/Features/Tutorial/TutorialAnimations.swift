import SwiftUI
import AppFlow

/// Illustration animée du mécanisme de chaque jeu, en tête de son tutoriel.
///
/// Tout est dessiné en SwiftUI, sans image externe. Une boucle continue montre le geste clé :
/// le palet qui rebondit, le cavalier qui saute, la rafle aux dames, les traînées Tron, le moulin
/// qui se forme. Si l'utilisateur a demandé Reduce Motion, une image fixe représentative s'affiche.
struct GameTutorialAnimation: View {
    let game: GameID
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                animation(phase: staticPhase)
            } else {
                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    animation(phase: (t.truncatingRemainder(dividingBy: loopDuration)) / loopDuration)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .background(background, in: RoundedRectangle(cornerRadius: Theme.Radius.surface))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.surface))
        .accessibilityHidden(true)
    }

    private var loopDuration: Double {
        switch game {
        case .airHockey: 4
        case .chess: 3
        case .draughts: 3.5
        case .tron: 3
        case .mill: 4
        }
    }

    private var staticPhase: Double { 0.5 }

    private var background: Color {
        game.isRealTime ? Theme.Arcade.void_ : Theme.Wood.paper
    }

    @ViewBuilder
    private func animation(phase: Double) -> some View {
        switch game {
        case .airHockey: AirHockeyDemo(phase: phase)
        case .chess: ChessDemo(phase: phase)
        case .draughts: DraughtsDemo(phase: phase)
        case .tron: TronDemo(phase: phase)
        case .mill: MillDemo(phase: phase)
        }
    }
}

// MARK: - Air hockey : le palet rebondit entre deux maillets

private struct AirHockeyDemo: View {
    let phase: Double

    /// Onde triangulaire 0→1→0 à vitesse constante : donne des segments droits avec rebond net.
    private func triangle(_ x: Double) -> Double {
        let f = x.truncatingRemainder(dividingBy: 1)
        return f < 0.5 ? f * 2 : 2 - f * 2
    }

    /// Lissage pour l'interception : le maillet accélère puis décélère, sans à-coup.
    private func smoothstep(_ x: Double) -> Double {
        let t = min(max(x, 0), 1)
        return t * t * (3 - 2 * t)
    }

    var body: some View {
        Canvas { context, size in
            let inset: CGFloat = 20
            let field = CGRect(x: inset, y: inset, width: size.width - inset * 2, height: size.height - inset * 2)
            let border = Path(roundedRect: field, cornerRadius: 12)
            context.stroke(border, with: .color(Theme.Arcade.cyan), lineWidth: 2.5)

            var mid = Path()
            mid.move(to: CGPoint(x: field.minX, y: field.midY))
            mid.addLine(to: CGPoint(x: field.maxX, y: field.midY))
            context.stroke(mid, with: .color(Theme.Arcade.magenta.opacity(0.5)), style: .init(lineWidth: 1.5, dash: [6, 5]))

            // Palet : rebond en lignes droites sur les quatre bandes (deux ondes triangulaires
            // de fréquences différentes → trajectoire en zigzag, jamais collée à un maillet).
            let margin: CGFloat = 14
            let nx = triangle(phase * 3)
            let ny = triangle(phase * 2 + 0.15)
            let puck = CGPoint(x: field.minX + margin + (field.width - margin * 2) * nx,
                               y: field.minY + margin + (field.height - margin * 2) * ny)
            context.fill(Path(ellipseIn: CGRect(x: puck.x - 7, y: puck.y - 7, width: 14, height: 14)),
                         with: .color(Theme.Arcade.amber))

            // Maillets : chacun garde son but au centre, et ne glisse vers le palet en x que
            // lorsqu'il approche de son côté. On défend, on ne colle pas.
            let puckYNorm = (puck.y - field.minY) / field.height   // 0 en haut, 1 en bas
            let topIntercept = smoothstep(Double(1 - puckYNorm - 0.4) / 0.6)
            let bottomIntercept = smoothstep(Double(puckYNorm - 0.4) / 0.6)
            let topX = field.midX + (puck.x - field.midX) * topIntercept
            let bottomX = field.midX + (puck.x - field.midX) * bottomIntercept
            let mallets = [
                (CGPoint(x: topX, y: field.minY + 22), Theme.Arcade.magenta),
                (CGPoint(x: bottomX, y: field.maxY - 22), Theme.Arcade.cyan),
            ]
            for (center, color) in mallets {
                let r: CGFloat = 15
                context.stroke(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                               with: .color(color), lineWidth: 3)
            }
        }
    }
}

// MARK: - Échecs : un cavalier saute en L

private struct ChessDemo: View {
    let phase: Double

    var body: some View {
        Canvas { context, size in
            let n = 4
            let boardSize = min(size.width, size.height) - 24
            let cell = boardSize / CGFloat(n)
            let origin = CGPoint(x: (size.width - boardSize) / 2, y: (size.height - boardSize) / 2)

            for row in 0..<n {
                for col in 0..<n {
                    let dark = (row + col) % 2 == 0
                    let rect = CGRect(x: origin.x + CGFloat(col) * cell, y: origin.y + CGFloat(row) * cell, width: cell, height: cell)
                    context.fill(Path(rect), with: .color(dark ? Theme.Wood.felt.opacity(0.5) : Theme.Wood.paper))
                }
            }

            // Cavalier : de (0,3) à (1,1), un saut en L, aller-retour.
            let from = CGPoint(x: 0.5, y: 3.5), to = CGPoint(x: 1.5, y: 1.5)
            let p = phase < 0.5 ? phase * 2 : (1 - phase) * 2
            let eased = 0.5 - cos(p * .pi) / 2
            let pos = CGPoint(x: origin.x + (from.x + (to.x - from.x) * eased) * cell,
                              y: origin.y + (from.y + (to.y - from.y) * eased) * cell)
            let lift = sin(eased * .pi) * 10
            context.draw(Text("♞").font(.system(size: cell * 0.72)).foregroundStyle(Theme.Umbrella.ink),
                         at: CGPoint(x: pos.x, y: pos.y - lift))
        }
    }
}

// MARK: - Dames : une prise par-dessus un pion

private struct DraughtsDemo: View {
    let phase: Double

    var body: some View {
        Canvas { context, size in
            let squares = 4
            let boardSize = min(size.width, size.height) - 24
            let cell = boardSize / CGFloat(squares)
            let origin = CGPoint(x: (size.width - boardSize) / 2, y: (size.height - boardSize) / 2)
            for row in 0..<squares {
                for col in 0..<squares {
                    let rect = CGRect(x: origin.x + CGFloat(col) * cell, y: origin.y + CGFloat(row) * cell, width: cell, height: cell)
                    context.fill(Path(rect), with: .color((row + col) % 2 == 1 ? Theme.Wood.wood : Theme.Wood.paper))
                }
            }
            func disc(_ c: CGPoint, _ color: Color, r: CGFloat) {
                context.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(color))
            }
            let r = cell * 0.34
            // Pion adverse en (2,2), capturé à mi-parcours.
            let captured = phase < 0.55
            if captured {
                disc(CGPoint(x: origin.x + 2.5 * cell, y: origin.y + 2.5 * cell), Theme.Wood.felt, r: r)
            }
            // Notre pion saute de (1,3) à (3,1).
            let from = CGPoint(x: 1.5, y: 3.5), to = CGPoint(x: 3.5, y: 1.5)
            let p = phase < 0.5 ? phase * 2 : (1 - phase) * 2
            let eased = 0.5 - cos(p * .pi) / 2
            let pos = CGPoint(x: origin.x + (from.x + (to.x - from.x) * eased) * cell,
                              y: origin.y + (from.y + (to.y - from.y) * eased) * cell)
            disc(CGPoint(x: pos.x, y: pos.y - sin(eased * .pi) * 12), Theme.Wood.paper, r: r)
            context.stroke(Path(ellipseIn: CGRect(x: pos.x - r, y: pos.y - sin(eased * .pi) * 12 - r, width: r * 2, height: r * 2)),
                           with: .color(Theme.Umbrella.ink.opacity(0.5)), lineWidth: 1.5)
        }
    }
}

// MARK: - Tron : deux traînées grandissent

private struct TronDemo: View {
    let phase: Double

    var body: some View {
        Canvas { context, size in
            let cell: CGFloat = 12
            let cols = Int(size.width / cell)
            let midCol = cols / 2
            let progress = phase < 0.85 ? phase / 0.85 : 0   // reset bref en fin de boucle
            let steps = Int(Double(Int(size.height / cell) / 2 - 1) * progress)

            func trail(fromTop: Bool, color: Color, colOffset: Int) {
                var path = Path()
                let startY = fromTop ? cell : size.height - cell
                let dir: CGFloat = fromTop ? 1 : -1
                for i in 0...max(steps, 0) {
                    let x = CGFloat(midCol + colOffset) * cell
                    let y = startY + dir * CGFloat(i) * cell
                    path.addRect(CGRect(x: x, y: y, width: cell - 3, height: cell - 3))
                }
                context.fill(path, with: .color(color.opacity(0.8)))
            }
            trail(fromTop: true, color: Theme.Arcade.magenta, colOffset: 1)
            trail(fromTop: false, color: Theme.Arcade.cyan, colOffset: -1)
        }
    }
}

// MARK: - Moulin : trois pions s'alignent

private struct MillDemo: View {
    let phase: Double

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height) - 30
            let origin = CGPoint(x: (size.width - side) / 2, y: (size.height - side) / 2)
            let step = side / 6
            func pt(_ gx: Int, _ gy: Int) -> CGPoint { CGPoint(x: origin.x + CGFloat(gx) * step, y: origin.y + CGFloat(gy) * step) }

            var rings = Path()
            for r in [0, 1, 2] {
                let a = pt(r, r), b = pt(6 - r, 6 - r)
                rings.addRect(CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y))
            }
            rings.move(to: pt(3, 0)); rings.addLine(to: pt(3, 2))
            rings.move(to: pt(3, 4)); rings.addLine(to: pt(3, 6))
            context.stroke(rings, with: .color(Theme.Umbrella.ink.opacity(0.7)), lineWidth: 2)

            // Trois pions sur la ligne haute, posés l'un après l'autre ; moulin surligné à la fin.
            let spots = [pt(0, 0), pt(3, 0), pt(6, 0)]
            let placed = min(3, Int(phase * 4))
            let complete = placed >= 3
            for (i, spot) in spots.enumerated() where i < placed {
                let r = step * 0.34
                context.fill(Path(ellipseIn: CGRect(x: spot.x - r, y: spot.y - r, width: r * 2, height: r * 2)),
                             with: .color(Theme.Wood.felt))
                if complete {
                    context.stroke(Path(ellipseIn: CGRect(x: spot.x - r, y: spot.y - r, width: r * 2, height: r * 2)),
                                   with: .color(Theme.Wood.hit), lineWidth: 3)
                }
            }
        }
    }
}
