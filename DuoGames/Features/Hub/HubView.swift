import SwiftUI
import AppFlow

/// Sélection des jeux. Éditorial, pas une grille de produits (DESIGN.md §0).
struct HubView: View {
    @Environment(FlowModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                header
                VStack(spacing: 0) {
                    ForEach(GameID.allCases, id: \.self) { game in
                        GameRow(
                            game: game,
                            isLocked: !model.isUnlocked(game),
                            isLead: game == GameID.allCases.first
                        ) {
                            model.send(.selectGame(game))
                        }
                        if game != GameID.allCases.last {
                            Divider().overlay(Theme.Umbrella.rule)
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("hub.gamesList")

                comingSoon
            }
            .padding(Theme.Space.l)
        }
        .safeAreaInset(edge: .bottom) { footer }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text("hub.title")
                .font(Theme.Typo.display(44))
            Text("hub.subtitle")
                .font(.body)
                .foregroundStyle(Theme.Umbrella.inkSecondary)
        }
        .foregroundStyle(Theme.Umbrella.ink)
        .accessibilityAddTraits(.isHeader)
    }

    /// Bandeau discret : promet la suite sans encombrer, ancre l'app dans une collection vivante.
    private var comingSoon: some View {
        HStack(spacing: Theme.Space.m) {
            // Grille de plateau : la collection de jeux qui s'agrandit, reliée au contenu (R-04).
            Image(systemName: "square.grid.2x2")
                .foregroundStyle(Theme.Umbrella.inkSecondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("hub.comingSoon.title")
                    .font(.subheadline.weight(.semibold))
                Text("hub.comingSoon.subtitle")
                    .font(.footnote)
                    .foregroundStyle(Theme.Umbrella.inkSecondary)
            }
            Spacer()
        }
        .padding(Theme.Space.m)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.surface)
                .strokeBorder(Theme.Umbrella.rule, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
        )
        .padding(.top, Theme.Space.l)
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        HStack(spacing: Theme.Space.m) {
            footerButton("nav.profile", symbol: "person.2") { model.send(.openProfile) }
            footerButton("nav.leaderboard", symbol: "trophy") { model.send(.openLeaderboard(nil)) }
            footerButton("nav.settings", symbol: "gearshape") { model.send(.openSettings) }
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.vertical, Theme.Space.m)
        .background(.bar)
    }

    private func footerButton(_ key: LocalizedStringKey, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(key, systemImage: symbol)
                .font(.footnote.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
        }
        .foregroundStyle(Theme.Umbrella.ink)
        // Le chrome du pied ne suit le Dynamic Type que jusqu'à une borne : au-delà,
        // il empièterait sur le contenu. La navigation reste toujours lisible et cliquable.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .accessibilityLabel(Text(key))
    }
}

private struct GameRow: View {
    let game: GameID
    let isLocked: Bool
    /// L'entrée de tête est plus grande : hiérarchie éditoriale, pas une liste de cartes identiques.
    var isLead = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.m) {
                // Palette disciplinée sur le hub (R-29) : un seul accent, celui du jeu en tête et
                // jouable. Les autres barres sont neutres ; la couleur de chaque jeu réapparaît dans
                // le jeu lui-même. Cela crée aussi un point focal unique sur le jeu offert.
                Rectangle()
                    .fill(isLead ? accent : Theme.Umbrella.rule)
                    .frame(width: isLead ? 6 : 4, height: isLead ? 60 : 44)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text(LocalizedStringKey(game.titleKey))
                        .font(Theme.Typo.display(isLead ? 40 : 28, weight: isLead ? .bold : .semibold))
                    Text(LocalizedStringKey(game.pitchKey))
                        .font(isLead ? .body : .subheadline)
                        .foregroundStyle(Theme.Umbrella.inkSecondary)
                }

                Spacer()

                if isLocked {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(Theme.Umbrella.inkSecondary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, isLead ? Theme.Space.l : Theme.Space.m)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.Umbrella.ink)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(LocalizedStringKey(game.titleKey)))
        .accessibilityValue(isLocked ? Text("hub.locked") : Text(""))
        .accessibilityHint(isLocked ? Text("hub.hint.locked") : Text("hub.hint.play"))
        .accessibilityAddTraits(.isButton)
    }

    private var accent: Color {
        switch game {
        case .airHockey: Theme.Accent.airHockey
        case .chess: Theme.Accent.chess
        case .draughts: Theme.Accent.draughts
        case .tron: Theme.Accent.tron
        case .mill: Theme.Accent.mill
        }
    }
}
