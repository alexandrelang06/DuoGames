import SwiftUI
import AppFlow
import MillEngine

/// Jeu du moulin. Trois carrés concentriques, 24 intersections, symétrique : parfait à plat.
struct MillView: View {
    @Environment(FlowModel.self) private var model
    @State private var game = MillGame()
    @State private var selection: Int?

    /// Coordonnées des 24 intersections sur une grille 7×7.
    private static let grid: [(Int, Int)] = [
        (0, 0), (3, 0), (6, 0),
        (1, 1), (3, 1), (5, 1),
        (2, 2), (3, 2), (4, 2),
        (0, 3), (1, 3), (2, 3), (4, 3), (5, 3), (6, 3),
        (2, 4), (3, 4), (4, 4),
        (1, 5), (3, 5), (5, 5),
        (0, 6), (3, 6), (6, 6),
    ]

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                banner(for: .black, rotated: true)
                Spacer(minLength: Theme.foldGutter)
                board(side: min(proxy.size.width, proxy.size.height * 0.62))
                Spacer(minLength: Theme.foldGutter)
                banner(for: .white, rotated: false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(Theme.Space.m)
        .background(Theme.Umbrella.paper)
        .onChange(of: game.state) { _, state in finish(state) }
    }

    private func board(side: CGFloat) -> some View {
        let inset = side * 0.08
        let step = (side - inset * 2) / 6
        func point(_ index: Int) -> CGPoint {
            let (gx, gy) = Self.grid[index]
            return CGPoint(x: inset + CGFloat(gx) * step, y: inset + CGFloat(gy) * step)
        }

        return ZStack {
            Canvas { context, _ in
                var path = Path()
                for square in 0..<3 {
                    let a = point([0, 3, 6][square]), c = point([23, 20, 17][square])
                    path.addRect(CGRect(x: a.x, y: a.y, width: c.x - a.x, height: c.y - a.y))
                }
                for (from, to) in [(1, 7), (9, 11), (12, 14), (16, 22)] {
                    path.move(to: point(from)); path.addLine(to: point(to))
                }
                context.stroke(path, with: .color(Theme.Umbrella.ink), lineWidth: 2.5)
            }
            ForEach(0..<MillBoard.pointCount, id: \.self) { index in
                pointView(index, radius: step * 0.36)
                    .position(point(index))
            }
        }
        .frame(width: side, height: side)
        .background(Theme.Wood.paper, in: RoundedRectangle(cornerRadius: Theme.Radius.surface))
    }

    private func pointView(_ index: Int, radius: CGFloat) -> some View {
        let owner = game.points[index]
        let isSelected = selection == index
        let isTarget = targets.contains(index)
        let isRemovable = removable.contains(index)

        return ZStack {
            Circle()
                .fill(owner == nil ? Theme.Umbrella.paper : (owner == .white ? Theme.Wood.paper : Theme.Wood.felt))
                .overlay(Circle().stroke(Theme.Umbrella.ink, lineWidth: owner == nil ? 2 : 1.5))
                .frame(width: owner == nil ? radius * 0.9 : radius * 2, height: owner == nil ? radius * 0.9 : radius * 2)
            if isSelected { Circle().stroke(Theme.Wood.brass, lineWidth: 4).frame(width: radius * 2.3, height: radius * 2.3) }
            if isTarget { Circle().fill(Theme.Umbrella.ink.opacity(0.3)).frame(width: radius * 0.8, height: radius * 0.8) }
            if isRemovable { Circle().stroke(Theme.Wood.hit, lineWidth: 4).frame(width: radius * 2.3, height: radius * 2.3) }
        }
        .frame(width: radius * 2.6, height: radius * 2.6)
        .contentShape(Circle())
        .onTapGesture { tap(index) }
    }

    private var targets: Set<Int> {
        guard case .awaitingMove = game.state, let selection else { return [] }
        return Set(game.destinations(from: selection))
    }

    private var removable: Set<Int> {
        guard case .awaitingRemoval(let player) = game.state else { return [] }
        return Set(game.removablePieces(for: player))
    }

    private func tap(_ index: Int) {
        switch game.state {
        case .awaitingPlacement(let player):
            if (try? game.place(at: index, by: player)) != nil { Feedback.play("game.place") }
        case .awaitingMove(let player):
            if let origin = selection, targets.contains(index) {
                if (try? game.move(from: origin, to: index, by: player)) != nil { Feedback.play("game.move") }
                selection = nil
            } else if game.points[index] == player {
                selection = (selection == index) ? nil : index
            } else {
                selection = nil
            }
        case .awaitingRemoval(let player):
            if (try? game.remove(at: index, by: player)) != nil { Feedback.play("game.capture") }
        case .victory, .draw:
            break
        }
    }

    private func finish(_ state: MillState) {
        let result: MatchResult? = switch state {
        case .victory(let player): .winner(player == .white ? .one : .two)
        case .draw: .draw
        default: nil
        }
        guard let result else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            model.send(.finishGame(result))
        }
    }

    private func banner(for player: MillPlayer, rotated: Bool) -> some View {
        let isActive = game.state.activePlayer == player && game.state != .victory(player)
        let status: LocalizedStringKey = switch game.state {
        case .awaitingRemoval: "mill.removePiece"
        case .awaitingPlacement: "mill.place"
        default: "game.yourTurn"
        }
        return HStack {
            Text(LocalizedStringKey(player.localizationKey))
                .font(Theme.Typo.display(22, weight: .semibold))
            Text("\(game.inHand(player))")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(Theme.Umbrella.inkSecondary)
            Spacer()
            if isActive {
                Text(status).font(.subheadline.weight(.semibold))
            }
            Button("game.quit") { model.send(.finishGame(.draw)) }
                .font(.footnote)
                .foregroundStyle(Theme.Umbrella.inkSecondary)
        }
        .padding(.horizontal, Theme.Space.m)
        .padding(.vertical, Theme.Space.s)
        .background(isActive ? Theme.Wood.brass.opacity(0.25) : .clear, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
        .rotationEffect(rotated ? .degrees(180) : .zero)
        .foregroundStyle(Theme.Umbrella.ink)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(isActive ? .updatesFrequently : [])
    }
}
