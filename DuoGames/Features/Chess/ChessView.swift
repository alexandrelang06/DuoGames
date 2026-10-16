import SwiftUI
import AppFlow
import ChessEngine

/// Plateau d'échecs tête-bêche. Les blancs jouent depuis le bas, les noirs depuis le haut,
/// et les pièces noires sont retournées pour être lues à l'endroit par leur joueur.
struct ChessView: View {
    @Environment(FlowModel.self) private var model
    @State private var game = ChessGame()
    @State private var selection: ChessSquare?
    @State private var pendingPromotion: [ChessMove] = []

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                turnBanner(for: .black, rotated: true)
                Spacer(minLength: Theme.foldGutter)
                board(side: min(proxy.size.width, proxy.size.height * 0.62))
                Spacer(minLength: Theme.foldGutter)
                turnBanner(for: .white, rotated: false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(Theme.Space.m)
        .background(Theme.Umbrella.paper)
        .overlay { promotionSheet }
        .onChange(of: game.outcome) { _, outcome in finish(outcome) }
    }

    // MARK: - Plateau

    private func board(side: CGFloat) -> some View {
        let cell = side / 8
        return VStack(spacing: 0) {
            ForEach((0..<8).reversed(), id: \.self) { rank in
                HStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { file in
                        squareView(ChessSquare(file, rank), cell: cell)
                    }
                }
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.control).stroke(Theme.Umbrella.ink, lineWidth: 2))
    }

    private func squareView(_ square: ChessSquare, cell: CGFloat) -> some View {
        let piece = game.board[square]
        let isDark = (square.file + square.rank) % 2 == 0
        let isSelected = selection == square
        let isTarget = legalTargets.contains(square)
        let isKingInCheck = piece?.kind == .king && piece?.color == game.sideToMove && game.isInCheck

        return ZStack {
            Rectangle().fill(isDark ? Theme.Wood.felt.opacity(0.55) : Theme.Wood.paper)
            if isSelected { Rectangle().fill(Theme.Wood.brass.opacity(0.55)) }
            if isKingInCheck { Rectangle().fill(Theme.Wood.hit.opacity(0.45)) }
            if isTarget {
                Circle()
                    .fill(Theme.Umbrella.ink.opacity(piece == nil ? 0.25 : 0.0))
                    .frame(width: cell * 0.3, height: cell * 0.3)
                if piece != nil {
                    Circle().stroke(Theme.Wood.hit, lineWidth: 3).padding(3)
                }
            }
            if let piece {
                ChessGlyphView(piece: piece, size: cell * 0.74)
                    .rotationEffect(piece.color == .black ? .degrees(180) : .zero)
                    .accessibilityLabel(Text(LocalizedStringKey(piece.kind.localizationKey)))
            }
        }
        .frame(width: cell, height: cell)
        .contentShape(Rectangle())
        .onTapGesture { tap(square) }
    }

    private var legalTargets: Set<ChessSquare> {
        guard let selection else { return [] }
        return Set(game.legalMoves(from: selection).map(\.destination))
    }

    // MARK: - Interaction

    private func tap(_ square: ChessSquare) {
        guard !game.isOver, pendingPromotion.isEmpty else { return }

        if let origin = selection {
            let candidates = game.legalMoves(from: origin).filter { $0.destination == square }
            if candidates.count > 1 {
                pendingPromotion = candidates
                return
            }
            if let move = candidates.first {
                let isCapture = game.board[move.destination] != nil || move.isEnPassant
                _ = try? game.apply(move)
                Feedback.play(isCapture ? "game.capture" : "game.move")
                selection = nil
                return
            }
        }

        if let piece = game.board[square], piece.color == game.sideToMove {
            selection = (selection == square) ? nil : square
            if selection != nil { Feedback.play("game.select") }
        } else {
            selection = nil
        }
    }

    private func finish(_ outcome: ChessOutcome) {
        let result: MatchResult? = switch outcome {
        case .ongoing: nil
        case .checkmate(let winner): .winner(winner == .white ? .one : .two)
        case .stalemate, .fiftyMoveRule, .threefoldRepetition, .insufficientMaterial: .draw
        }
        guard let result else { return }
        Feedback.play("game.victory")
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            model.send(.finishGame(result))
        }
    }

    // MARK: - Bandeaux tête-bêche

    private func turnBanner(for color: ChessColor, rotated: Bool) -> some View {
        let isActive = game.sideToMove == color && !game.isOver
        return HStack {
            Text(LocalizedStringKey(color.localizationKey))
                .font(Theme.Typo.display(22, weight: .semibold))
            Spacer()
            if isActive {
                Text(game.isInCheck ? "result.check" : "game.yourTurn")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(game.isInCheck ? Theme.Wood.hit : Theme.Umbrella.ink)
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

    // MARK: - Promotion

    @ViewBuilder
    private var promotionSheet: some View {
        if !pendingPromotion.isEmpty {
            ZStack {
                Color.black.opacity(0.35).ignoresSafeArea()
                HStack(spacing: Theme.Space.m) {
                    ForEach(pendingPromotion, id: \.self) { move in
                        Button {
                            _ = try? game.apply(move)
                            pendingPromotion = []
                            selection = nil
                        } label: {
                            ChessGlyphView(piece: ChessPiece(game.sideToMove, move.promotion ?? .queen), size: 40)
                                .frame(width: 64, height: 64)
                                .background(Theme.Wood.paper, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
                        }
                    }
                }
                .padding(Theme.Space.l)
                .background(Theme.Umbrella.paper, in: RoundedRectangle(cornerRadius: Theme.Radius.sheet))
            }
        }
    }

    // MARK: - Glyphes

}

/// Pièce d'échecs à silhouette unique : la même forme pleine pour les deux camps, seule la couleur
/// change. Un contour la rend lisible sur les cases claires comme sombres. Placeholders sobres
/// (DESIGN.md §3), en attendant d'éventuelles illustrations.
private struct ChessGlyphView: View {
    let piece: ChessPiece
    let size: CGFloat

    /// Toujours les glyphes pleins Unicode, choisis par type et non par couleur.
    /// Le sélecteur de variation texte (U+FE0E) force un rendu monochrome : sans lui, iOS affiche
    /// certains symboles (le pion notamment) en emoji noir figé qui ignore `foregroundStyle`, et les
    /// pions blancs restaient noirs.
    private var glyph: String {
        let base: String = switch piece.kind {
        case .king: "♚"
        case .queen: "♛"
        case .rook: "♜"
        case .bishop: "♝"
        case .knight: "♞"
        case .pawn: "♟"
        }
        return base + "\u{FE0E}"
    }

    // Blancs franchement blancs, noirs franchement noirs : la couleur du remplissage porte la
    // distinction. Le contour reste fin, juste pour détacher la pièce de la case.
    private var fill: Color { piece.color == .white ? Color(hex: 0xFBF7EF) : Color(hex: 0x141414) }
    private var outline: Color { piece.color == .white ? Color(hex: 0x141414) : Color(hex: 0xFBF7EF) }
    private var outlineWidth: CGFloat { size * 0.018 }

    var body: some View {
        ZStack {
            // Contour fin : quatre copies décalées, assez pour l'arête sans noircir la pièce.
            ForEach(0..<4, id: \.self) { i in
                let angle = Double(i) / 4 * 2 * .pi + .pi / 4
                Text(glyph)
                    .font(.system(size: size))
                    .foregroundStyle(outline)
                    .offset(x: cos(angle) * outlineWidth, y: sin(angle) * outlineWidth)
            }
            Text(glyph)
                .font(.system(size: size))
                .foregroundStyle(fill)
        }
    }
}
