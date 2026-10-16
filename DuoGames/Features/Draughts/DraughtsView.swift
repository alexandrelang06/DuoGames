import SwiftUI
import AppFlow
import DraughtsEngine

/// Dames internationales tête-bêche. Les pions sont des disques : aucune rotation nécessaire.
struct DraughtsView: View {
    @Environment(FlowModel.self) private var model
    @State private var game = DraughtsGame()
    @State private var selection: Square?

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
        .onChange(of: game.outcome) { _, outcome in finish(outcome) }
    }

    private func board(side: CGFloat) -> some View {
        let cell = side / CGFloat(DraughtsBoard.size)
        return VStack(spacing: 0) {
            ForEach(0..<DraughtsBoard.size, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<DraughtsBoard.size, id: \.self) { col in
                        squareView(Square(row, col), cell: cell)
                    }
                }
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.control).stroke(Theme.Wood.brass, lineWidth: 3))
    }

    private func squareView(_ square: Square, cell: CGFloat) -> some View {
        let piece = game.board[square]
        let isTarget = targets[square] != nil
        let isSelected = selection == square

        return ZStack {
            Rectangle().fill(square.isPlayable ? Theme.Wood.wood : Theme.Wood.paper)
            if isSelected { Rectangle().fill(Theme.Wood.brass.opacity(0.6)) }
            if isTarget {
                Circle().fill(Theme.Umbrella.ink.opacity(0.3))
                    .frame(width: cell * 0.35, height: cell * 0.35)
            }
            if let piece {
                Circle()
                    .fill(piece.color == .white ? Theme.Wood.paper : Theme.Wood.felt)
                    .overlay(Circle().stroke(Theme.Umbrella.ink.opacity(0.6), lineWidth: 1.5))
                    .overlay {
                        if piece.isKing {
                            Image(systemName: "crown.fill")
                                .font(.system(size: cell * 0.4))
                                .foregroundStyle(Theme.Wood.brass)
                        }
                    }
                    .padding(cell * 0.12)
                    .accessibilityLabel(Text(LocalizedStringKey(piece.color.localizationKey)))
            }
        }
        .frame(width: cell, height: cell)
        .contentShape(Rectangle())
        .onTapGesture { tap(square) }
    }

    /// Destinations légales depuis la sélection, avec le coup complet associé.
    private var targets: [Square: DraughtsMove] {
        guard let selection else { return [:] }
        return Dictionary(game.legalMoves(from: selection).map { ($0.destination, $0) }, uniquingKeysWith: { a, _ in a })
    }

    private func tap(_ square: Square) {
        guard !game.isOver else { return }
        if let move = targets[square] {
            _ = try? game.apply(move)
            Feedback.play(move.isCapture ? "game.capture" : "game.move")
            selection = nil
            return
        }
        if let piece = game.board[square], piece.color == game.sideToMove,
           !game.legalMoves(from: square).isEmpty {
            selection = (selection == square) ? nil : square
        } else {
            selection = nil
        }
    }

    private func finish(_ outcome: DraughtsOutcome) {
        let result: MatchResult? = switch outcome {
        case .ongoing: nil
        case .victory(let color): .winner(color == .white ? .one : .two)
        case .draw: .draw
        }
        guard let result else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            model.send(.finishGame(result))
        }
    }

    private func banner(for color: DraughtsColor, rotated: Bool) -> some View {
        let isActive = game.sideToMove == color && !game.isOver
        let mustCapture = isActive && game.legalMoves.first?.isCapture == true
        return HStack {
            Text(LocalizedStringKey(color.localizationKey))
                .font(Theme.Typo.display(22, weight: .semibold))
            Spacer()
            if isActive {
                Text(mustCapture ? "draughts.mustCapture" : "game.yourTurn")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(mustCapture ? Theme.Wood.hit : Theme.Umbrella.ink)
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
