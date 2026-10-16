import SwiftUI
import AppFlow
import AirHockeyEngine

/// Air hockey. Le terrain occupe tout l'écran ; la ligne médiane coïncide avec le pli.
/// Deux zones de toucher indépendantes, donc deux doigts simultanés.
struct AirHockeyView: View {
    @Environment(FlowModel.self) private var model
    @State private var game = AirHockeyGame(spec: TableSpec(width: 400, height: 700))
    @State private var lastTick: ContinuousClock.Instant?

    var body: some View {
        ZStack {
            Theme.Arcade.void_.ignoresSafeArea()
            VStack(spacing: Theme.Space.s) {
                banner(.far).rotationEffect(.degrees(180))
                GeometryReader { proxy in
                    let scale = min(proxy.size.width / game.spec.width, proxy.size.height / game.spec.height)
                    let offset = CGPoint(x: (proxy.size.width - game.spec.width * scale) / 2,
                                         y: (proxy.size.height - game.spec.height * scale) / 2)
                    ZStack {
                        table(scale: scale, offset: offset)
                        touchZones(scale: scale, offset: offset)
                    }
                    .coordinateSpace(name: "table")
                }
                banner(.near)
            }
            .padding(.horizontal, Theme.Space.m)
        }
        .task { await run() }
    }

    private func banner(_ player: AirHockeyPlayer) -> some View {
        let color = player == .near ? Theme.Arcade.cyan : Theme.Arcade.magenta
        return HStack(alignment: .firstTextBaseline) {
            Text(LocalizedStringKey(player.localizationKey))
                .font(Theme.Typo.score(14))
                .foregroundStyle(color.opacity(0.8))
            Spacer()
            Text("\(game.score(player))")
                .font(Theme.Typo.score(36))
                .foregroundStyle(color)
            Spacer()
            Button("game.quit") { model.send(.finishGame(.draw)) }
                .font(.footnote)
                // Pleine opacité pour rester au-dessus du contraste AA sur fond sombre (R-25).
                .foregroundStyle(color)
        }
        .padding(.horizontal, Theme.Space.s)
    }

    // MARK: - Rendu

    private func table(scale: CGFloat, offset: CGPoint) -> some View {
        Canvas { context, _ in
            func map(_ v: Vector2D) -> CGPoint { CGPoint(x: offset.x + v.x * scale, y: offset.y + v.y * scale) }
            let spec = game.spec
            let rect = CGRect(x: offset.x, y: offset.y, width: spec.width * scale, height: spec.height * scale)

            // Chrome du terrain : le glow suit la géométrie (DESIGN.md §4).
            let field = Path(roundedRect: rect, cornerRadius: 18)
            context.stroke(field, with: .color(Theme.Arcade.cyan), lineWidth: 3)
            context.stroke(field, with: .color(Theme.Arcade.cyan.opacity(0.25)), lineWidth: 12)

            // Ligne médiane sur le pli, gouttière de 24 pt de part et d'autre laissée vide.
            var mid = Path()
            mid.move(to: map(Vector2D(x: 0, y: spec.midY)))
            mid.addLine(to: map(Vector2D(x: spec.width, y: spec.midY)))
            context.stroke(mid, with: .color(Theme.Arcade.magenta.opacity(0.5)), style: StrokeStyle(lineWidth: 2, dash: [10, 8]))

            // Cages.
            for y in [0.0, spec.height] {
                var goal = Path()
                goal.move(to: map(Vector2D(x: spec.goalMinX, y: y)))
                goal.addLine(to: map(Vector2D(x: spec.goalMaxX, y: y)))
                context.stroke(goal, with: .color(Theme.Arcade.amber), lineWidth: 6)
            }

            // Maillets.
            for player in AirHockeyPlayer.allCases {
                let center = map(game.mallet(player))
                let r = spec.malletRadius * scale
                let color = player == .near ? Theme.Arcade.cyan : Theme.Arcade.magenta
                context.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                             with: .color(color.opacity(0.35)))
                context.stroke(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                               with: .color(color), lineWidth: 3)
            }

            // Palet.
            let puck = map(game.puckPosition)
            let pr = spec.puckRadius * scale
            context.fill(Path(ellipseIn: CGRect(x: puck.x - pr, y: puck.y - pr, width: pr * 2, height: pr * 2)),
                         with: .color(Theme.Arcade.amber))
        }
    }

    // MARK: - Toucher

    private func touchZones(scale: CGFloat, offset: CGPoint) -> some View {
        VStack(spacing: 0) {
            zone(for: .far, scale: scale, offset: offset)
            zone(for: .near, scale: scale, offset: offset)
        }
    }

    private func zone(for player: AirHockeyPlayer, scale: CGFloat, offset: CGPoint) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("table"))
                    .onChanged { value in
                        // `value.location` est dans le repère commun de la table, pas dans la zone.
                        let raw = Vector2D(x: Double((value.location.x - offset.x) / scale),
                                           y: Double((value.location.y - offset.y) / scale))
                        game.moveMallet(player, to: raw)
                    }
            )
    }

    // MARK: - Boucle

    private func run() async {
        let clock = ContinuousClock()
        var last = clock.now
        while !Task.isCancelled, !game.isOver {
            let now = clock.now
            let dt = min(Double((now - last).components.attoseconds) / 1e18, 1.0 / 30)
            last = now
            for event in game.tick(dt) {
                Feedback.play(event.eventKey)
            }
            try? await Task.sleep(for: .milliseconds(8))
        }
        guard !Task.isCancelled, let winner = game.winner else { return }
        try? await Task.sleep(for: .seconds(1.2))
        model.send(.finishGame(.winner(winner == .near ? .one : .two)))
    }
}
