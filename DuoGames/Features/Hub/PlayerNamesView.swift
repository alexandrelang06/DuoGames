import SwiftUI
import AppFlow

/// Étape d'onboarding : saisir les prénoms des deux joueurs au premier lancement.
///
/// Purement local (aucun compte, aucun réseau). Les prénoms sont facultatifs : on peut passer, et
/// des libellés par défaut (« Joueur 1 / 2 ») prennent le relais. Modifiable ensuite dans l'espace joueur.
struct PlayerNamesView: View {
    @Environment(FlowModel.self) private var model
    @AppStorage("onboarding.namesEntered") private var namesEntered = false
    @State private var one = ""
    @State private var two = ""
    @FocusState private var focus: Seat?

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            // Le haut défile (clavier ouvert, texte agrandi) ; les boutons restent épinglés en bas.
            ScrollView {
                VStack(spacing: Theme.Space.xl) {
                    VStack(spacing: Theme.Space.s) {
                        Text("names.title")
                            .font(Theme.Typo.display(32))
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                        Text("names.subtitle")
                            .font(.body)
                            .foregroundStyle(Theme.Umbrella.inkSecondary)
                            .multilineTextAlignment(.center)
                    }
                    VStack(spacing: Theme.Space.m) {
                        nameField(seat: .one, text: $one, accent: Theme.Accent.airHockey)
                        nameField(seat: .two, text: $two, accent: Theme.Accent.tron)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Space.xxl)
            }
            .scrollBounceBehavior(.basedOnSize)

            Button("names.continue") { commit() }
                .buttonStyle(PrimaryButtonStyle())
            Button("onboarding.skip") { commit() }
                .foregroundStyle(Theme.Umbrella.inkSecondary)
                .frame(maxWidth: .infinity)
        }
        .padding(Theme.Space.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Umbrella.paper)
        .foregroundStyle(Theme.Umbrella.ink)
        .onAppear {
            one = model.flow.profiles.profile(.one).name
            two = model.flow.profiles.profile(.two).name
        }
    }

    private func nameField(seat: Seat, text: Binding<String>, accent: Color) -> some View {
        HStack(spacing: Theme.Space.m) {
            Circle().fill(accent).frame(width: 28, height: 28)
                .accessibilityHidden(true)
            TextField(LocalizedStringKey(seat.localizationKey), text: text)
                .font(.body)
                .focused($focus, equals: seat)
                .submitLabel(seat == .one ? .next : .done)
                .onSubmit { focus = seat == .one ? .two : nil }
        }
        .padding(Theme.Space.m)
        .background(Theme.Umbrella.ink.opacity(0.04), in: RoundedRectangle(cornerRadius: Theme.Radius.control))
        .accessibilityElement(children: .combine)
    }

    private func commit() {
        model.rename(.one, to: one)
        model.rename(.two, to: two)
        namesEntered = true
    }
}
