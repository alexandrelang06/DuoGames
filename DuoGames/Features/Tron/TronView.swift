import SwiftUI
import AppFlow
import TronEngine

/// Duel Tron. Chaque joueur pilote depuis sa moitié par glissement ; le joueur d'en face
/// a ses commandes inversées pour que « vers le haut » reste vers le haut de son point de vue.
struct TronView: View {
    @Environment(FlowModel.self) private var model
    @State private var game = TronGame(width: 40, height: 60)
    @State private var countdown = 3

    private static let tickInterval: Duration = .milliseconds(90)

    var body: some View {
        ZStack {
            Theme.Arcade.void_.ignoresSafeArea()
            GeometryReader { proxy in
                ZStack {
                    arena(in: proxy.size)
                    controls(in: proxy.size)
                    if countdown > 0 {
                        Text("\(countdown)")
                            .font(Theme.Typo.score(96))
                            .foregroundStyle(Theme.Arcade.amber)
                    }
                }
            }
            scoreOverlay
        }
        .task { await run() }
    }

    // MARK: - Rendu

    private func arena(in size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let cell = min(canvasSize.width / CGFloat(game.width), canvasSize.height / CGFloat(game.height))
            let origin = CGPoint(x: (canvasSize.width - cell * CGFloat(game.width)) / 2,
                                 y: (canvasSize.height - cell * CGFloat(game.height)) / 2)

            // Grille en perspective plate : structure du glow (DESIGN.md §4).
            var grid = Path()
            for x in stride(from: 0, through: game.width, by: 5) {
                grid.move(to: CGPoint(x: origin.x + CGFloat(x) * cell, y: origin.y))
                grid.addLine(to: CGPoint(x: origin.x + CGFloat(x) * cell, y: origin.y + CGFloat(game.height) * cell))
            }
            for y in stride(from: 0, through: game.height, by: 5) {
                grid.move(to: CGPoint(x: origin.x, y: origin.y + CGFloat(y) * cell))
                grid.addLine(to: CGPoint(x: origin.x + CGFloat(game.width) * cell, y: origin.y + CGFloat(y) * cell))
            }
            context.stroke(grid, with: .color(Theme.Arcade.cyan.opacity(0.12)), lineWidth: 1)

            // Ligne médiane sur le pli, avec sa gouttière.
            let midY = origin.y + CGFloat(game.height) * cell / 2
            var mid = Path()
            mid.move(to: CGPoint(x: origin.x, y: midY))
            mid.addLine(to: CGPoint(x: origin.x + CGFloat(game.width) * cell, y: midY))
            context.stroke(mid, with: .color(Theme.Arcade.magenta.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [6, 6]))

            for rider in TronRider.allCases {
                let color = rider == .cyan ? Theme.Arcade.cyan : Theme.Arcade.magenta
                var trail = Path()
                for point in game.trail(of: rider) {
                    trail.addRect(CGRect(x: origin.x + CGFloat(point.x) * cell, y: origin.y + CGFloat(point.y) * cell,
                                         width: cell, height: cell).insetBy(dx: cell * 0.1, dy: cell * 0.1))
                }
                context.fill(trail, with: .color(color.opacity(0.75)))

                let head = game.position(of: rider)
                let headRect = CGRect(x: origin.x + CGFloat(head.x) * cell, y: origin.y + CGFloat(head.y) * cell,
                                      width: cell, height: cell)
                context.fill(Path(ellipseIn: headRect), with: .color(color))
            }
        }
        .padding(Theme.Space.m)
    }

    private var scoreOverlay: some View {
        VStack {
            label(for: .magenta).rotationEffect(.degrees(180))
            Spacer()
            label(for: .cyan)
        }
        .padding(Theme.Space.m)
    }

    private func label(for rider: TronRider) -> some View {
        HStack {
            Text(LocalizedStringKey(rider.localizationKey))
                .font(Theme.Typo.score(18))
                .foregroundStyle(rider == .cyan ? Theme.Arcade.cyan : Theme.Arcade.magenta)
            Spacer()
            Button("game.quit") { model.send(.finishGame(.draw)) }
                .font(.footnote)
                // Pleine opacité : à 60% le contraste tombait à 2,7:1, sous le minimum AA (R-25).
                .foregroundStyle(Theme.Arcade.cyan)
        }
    }

    // MARK: - Commandes

    /// Deux zones de glissement, une par moitié. Multi-touch : deux vues, deux gestes.
    private func controls(in size: CGSize) -> some View {
        VStack(spacing: 0) {
            steeringZone(for: .magenta, inverted: true)
            steeringZone(for: .cyan, inverted: false)
        }
    }

    private func steeringZone(for rider: TronRider, inverted: Bool) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 12)
                    .onEnded { value in
                        let dx = value.translation.width, dy = value.translation.height
                        var direction: Direction = abs(dx) > abs(dy) ? (dx > 0 ? .right : .left) : (dy > 0 ? .down : .up)
                        if inverted { direction = direction.opposite }
                        if game.steer(rider, direction) { Feedback.play("tron.turn") }
                    }
            )
    }

    // MARK: - Boucle

    private func run() async {
        for step in stride(from: 3, through: 1, by: -1) {
            countdown = step
            try? await Task.sleep(for: .seconds(1))
        }
        countdown = 0
        while !Task.isCancelled, game.isRunning {
            game.tick()
            try? await Task.sleep(for: Self.tickInterval)
        }
        guard !Task.isCancelled else { return }
        Feedback.play("tron.crash")
        try? await Task.sleep(for: .milliseconds(400))
        Feedback.play("tron.victory")
        let result: MatchResult = switch game.outcome {
        case .victory(.cyan): .winner(.one)
        case .victory(.magenta): .winner(.two)
        default: .draw
        }
        try? await Task.sleep(for: .seconds(1.2))
        model.send(.finishGame(result))
    }
}
