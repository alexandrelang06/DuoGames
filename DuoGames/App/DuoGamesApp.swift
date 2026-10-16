import SwiftUI
import Diagnostics

@main
struct DuoGamesApp: App {
    @State private var model = FlowModel()
    @State private var store = Store(productID: "com.duogames.unlock.collection")

    init() {
        DiagnosticsCenter.shared.start()
        GameCenterLeaderboard.shared.authenticate()
        Feedback.preloadAll()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(store)
                .task { await store.load() }
        }
    }
}
