import SwiftUI

/// Écran de lancement animé. Le nom de l'app en Zilla Slab sur le fond crème, avec deux pastilles
/// (les deux joueurs) qui se rejoignent : le motif d'identité de « deux joueurs, un appareil ».
/// S'efface tout seul vers le reste de l'app.
struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            Theme.Umbrella.paper.ignoresSafeArea()
            VStack(spacing: Theme.Space.l) {
                ZStack {
                    Circle()
                        .fill(Theme.Accent.airHockey)
                        .frame(width: 34, height: 34)
                        .offset(x: appeared ? -13 : -60)
                    Circle()
                        .fill(Theme.Accent.tron)
                        .frame(width: 34, height: 34)
                        .offset(x: appeared ? 13 : 60)
                }
                .accessibilityHidden(true)

                Text("hub.title")
                    .font(Theme.Typo.display(40))
                    .foregroundStyle(Theme.Umbrella.ink)
                    .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            guard !reduceMotion else { appeared = true; return }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { appeared = true }
        }
    }
}
