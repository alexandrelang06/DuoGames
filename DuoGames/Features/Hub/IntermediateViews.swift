import SwiftUI
import AppFlow

// MARK: - Guidage de posture

struct PostureGuidanceView: View {
    @Environment(FlowModel.self) private var model
    let game: GameID

    var body: some View {
        VStack(spacing: Theme.Space.xl) {
            Spacer()
            Image(systemName: "iphone.landscape")
                .font(.system(size: 88, weight: .thin))
                .accessibilityHidden(true)
            Text("guidance.layFlat")
                .font(Theme.Typo.display(30))
                .accessibilityAddTraits(.isHeader)
                .multilineTextAlignment(.center)
            Text("guidance.needsFlat")
                .font(.body)
                .foregroundStyle(Theme.Umbrella.inkSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            // Sans capteur de charnière (SDK 26.5), le joueur confirme lui-même.
            Button("guidance.ready") { model.send(.postureBecameReady) }
                .buttonStyle(PrimaryButtonStyle())
            Button("nav.back") { model.send(.backToHub) }
                .buttonStyle(SecondaryButtonStyle())
        }
        .padding(Theme.Space.l)
        .foregroundStyle(Theme.Umbrella.ink)
    }
}

// MARK: - Tutoriel

struct TutorialView: View {
    @Environment(FlowModel.self) private var model
    let game: GameID

    /// Le texte du tutoriel est une chaîne à paragraphes séparés par une ligne vide.
    private var paragraphs: [String] {
        let raw = String(localized: String.LocalizationValue(game.tutorialKey))
        return raw.components(separatedBy: "\n\n").filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    GameTutorialAnimation(game: game)

                    Text(LocalizedStringKey(game.titleKey))
                        .font(Theme.Typo.display(40))
                        .accessibilityAddTraits(.isHeader)

                    VStack(alignment: .leading, spacing: Theme.Space.m) {
                        ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.m) {
                                Text("\(index + 1)")
                                    .font(Theme.Typo.display(20, weight: .bold))
                                    .foregroundStyle(accent)
                                    .frame(width: 26, alignment: .leading)
                                    .accessibilityHidden(true)
                                Text(paragraph)
                                    .font(.body)
                                    .foregroundStyle(Theme.Umbrella.inkSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(Theme.Space.l)
            }

            Button("tutorial.start") { model.send(.dismissTutorial) }
                .buttonStyle(PrimaryButtonStyle())
                .padding([.horizontal, .bottom], Theme.Space.l)
        }
        .foregroundStyle(Theme.Umbrella.ink)
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

// MARK: - Fin de partie

struct GameOverView: View {
    @Environment(FlowModel.self) private var model
    let game: GameID
    let result: MatchResult

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            ScrollView {
                VStack(spacing: Theme.Space.s) {
                    Text(headline)
                        .font(Theme.Typo.display(44))
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    if let winner = result.winner {
                        Text(winnerName(winner))
                            .font(.title3)
                            .foregroundStyle(Theme.Umbrella.inkSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Space.xxl)
            }
            .scrollBounceBehavior(.basedOnSize)

            Button("result.rematch") { model.send(.rematch) }
                .buttonStyle(PrimaryButtonStyle())
            Button("result.backToHub") { model.send(.backToHub) }
                .buttonStyle(SecondaryButtonStyle())
        }
        .padding(Theme.Space.l)
        .foregroundStyle(Theme.Umbrella.ink)
    }

    private var headline: LocalizedStringKey {
        result.winner == nil ? "result.draw" : "result.victory"
    }

    private func winnerName(_ seat: Seat) -> String {
        let name = model.flow.profiles.profile(seat).name
        return name.isEmpty ? String(localized: String.LocalizationValue(seat.localizationKey)) : name
    }
}

// MARK: - Déblocage (DESIGN.md §6.3)

struct UnlockView: View {
    @Environment(FlowModel.self) private var model
    @Environment(Store.self) private var store
    @State private var isWorking = false
    let origin: UnlockOrigin

    var body: some View {
        VStack(spacing: 0) {
            // Bouton discret pour fermer, en haut : jamais de piège, on peut toujours sortir.
            HStack {
                Spacer()
                Button {
                    Feedback.play("game.select")
                    model.send(.purchaseCancelled)
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.Umbrella.inkSecondary)
                        .padding(Theme.Space.s)
                }
                .accessibilityLabel("unlock.later")
            }
            .padding(.horizontal, Theme.Space.m)
            .padding(.top, Theme.Space.s)

            ScrollView {
                VStack(spacing: Theme.Space.l) {
                    hero
                    gamesGrid
                    trust
                }
                .padding(.horizontal, Theme.Space.l)
                .padding(.bottom, Theme.Space.l)
            }

            purchaseBar
        }
        .foregroundStyle(Theme.Umbrella.ink)
        .task { if store.product == nil { await store.load() } }
    }

    // Accroche : quatre pastilles colorées empilées, titre, promesse.
    private var hero: some View {
        VStack(spacing: Theme.Space.m) {
            ZStack {
                ForEach(Array(model.flow.catalog.paidGames.enumerated()), id: \.element) { index, game in
                    Circle()
                        .fill(accent(game))
                        .frame(width: 56, height: 56)
                        .overlay(Circle().stroke(Theme.Umbrella.paper, lineWidth: 3))
                        .offset(x: CGFloat(index - 2) * 34)
                }
            }
            .frame(height: 60)
            .accessibilityHidden(true)

            Text("unlock.title")
                .font(Theme.Typo.display(34))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text("unlock.subtitle")
                .font(.body)
                .foregroundStyle(Theme.Umbrella.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Theme.Space.m)
    }

    // Chaque jeu débloqué, avec son accent et son pitch : on montre la valeur, pas une liste sèche.
    private var gamesGrid: some View {
        VStack(spacing: Theme.Space.s) {
            ForEach(model.flow.catalog.paidGames, id: \.self) { game in
                HStack(spacing: Theme.Space.m) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(accent(game))
                        .frame(width: 4, height: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey(game.titleKey))
                            .font(Theme.Typo.display(20, weight: .semibold))
                        Text(LocalizedStringKey(game.pitchKey))
                            .font(.footnote)
                            .foregroundStyle(Theme.Umbrella.inkSecondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(accent(game))
                }
                .padding(Theme.Space.m)
                .background(Theme.Umbrella.ink.opacity(0.04), in: RoundedRectangle(cornerRadius: Theme.Radius.control))
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var trust: some View {
        VStack(spacing: Theme.Space.xs) {
            Label("unlock.trust.once", systemImage: "checkmark.seal")
            Label("unlock.trust.noSub", systemImage: "xmark.circle")
            Label("unlock.trust.family", systemImage: "person.2")
        }
        .font(.footnote)
        .foregroundStyle(Theme.Umbrella.inkSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var purchaseBar: some View {
        VStack(spacing: Theme.Space.s) {
            // État de chargement / erreur visibles (R-27), plus de bouton désactivé en silence.
            if store.isLoading {
                HStack(spacing: Theme.Space.s) {
                    ProgressView()
                    Text("unlock.loading").font(.footnote).foregroundStyle(Theme.Umbrella.inkSecondary)
                }
            } else if store.product == nil {
                VStack(spacing: Theme.Space.xs) {
                    Text("unlock.unavailable")
                        .font(.footnote)
                        .foregroundStyle(Theme.Umbrella.inkSecondary)
                        .multilineTextAlignment(.center)
                    Button("unlock.retry") { Task { await store.load() } }
                        .font(.footnote.weight(.semibold))
                }
            } else {
                Button {
                    Task { await buy() }
                } label: {
                    HStack {
                        Text("unlock.buy")
                        Text("·").opacity(0.5)
                        Text(store.displayPrice).monospacedDigit()
                    }
                }
                .buttonStyle(PrimaryButtonStyle(tint: Theme.Accent.airHockey))
                .disabled(isWorking)

                Button("unlock.restore") { Task { await restore() } }
                    .font(.footnote)
                    .foregroundStyle(Theme.Umbrella.inkSecondary)
                    .disabled(isWorking)
            }
        }
        .padding(Theme.Space.l)
        .background(.bar)
    }

    private func accent(_ game: GameID) -> Color {
        switch game {
        case .airHockey: Theme.Accent.airHockey
        case .chess: Theme.Accent.chess
        case .draughts: Theme.Accent.draughts
        case .tron: Theme.Accent.tron
        case .mill: Theme.Accent.mill
        }
    }

    private func buy() async {
        isWorking = true
        defer { isWorking = false }
        if await store.purchase() {
            Feedback.play("tron.victory")
            model.send(.purchaseSucceeded)
        }
    }

    private func restore() async {
        isWorking = true
        defer { isWorking = false }
        if await store.restore() { model.send(.restoreSucceeded) }
    }
}

// MARK: - Espace joueur

struct ProfileView: View {
    @Environment(FlowModel.self) private var model
    @State private var nameOne = ""
    @State private var nameTwo = ""

    var body: some View {
        NavigationStack {
            List {
                Section("profile.rename") {
                    TextField("seat.one", text: $nameOne)
                        .onSubmit { model.rename(.one, to: nameOne) }
                    TextField("seat.two", text: $nameTwo)
                        .onSubmit { model.rename(.two, to: nameTwo) }
                }
                Section {
                    statRow(.one)
                    statRow(.two)
                }
                Section("profile.duels") {
                    if model.flow.profiles.recentDuels.isEmpty {
                        Text("—").foregroundStyle(Theme.Umbrella.inkSecondary)
                    }
                    ForEach(Array(model.flow.profiles.recentDuels.enumerated()), id: \.offset) { _, duel in
                        HStack {
                            Text(LocalizedStringKey(duel.game.titleKey))
                            Spacer()
                            Text(resultLabel(duel.result))
                                .foregroundStyle(Theme.Umbrella.inkSecondary)
                        }
                    }
                }
                Section {
                    Text("profile.privacy")
                        .font(.footnote)
                        .foregroundStyle(Theme.Umbrella.inkSecondary)
                }
            }
            .navigationTitle("profile.title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("nav.close") { model.send(.backToHub) }
                }
            }
        }
        .onAppear {
            nameOne = model.flow.profiles.profile(.one).name
            nameTwo = model.flow.profiles.profile(.two).name
        }
    }

    private func statRow(_ seat: Seat) -> some View {
        HStack {
            Text(LocalizedStringKey(seat.localizationKey))
            Spacer()
            Text("\(model.flow.profiles.wins(seat))")
                .font(.body.monospacedDigit().weight(.semibold))
            Text("profile.wins").foregroundStyle(Theme.Umbrella.inkSecondary)
        }
    }

    private func resultLabel(_ result: MatchResult) -> LocalizedStringKey {
        switch result {
        case .winner(let seat): LocalizedStringKey(seat.localizationKey)
        case .draw: "result.draw"
        }
    }
}

// MARK: - Réglages et classement

struct SettingsView: View {
    @Environment(FlowModel.self) private var model
    @AppStorage("settings.sound") private var sound = true
    @AppStorage("settings.haptics") private var haptics = true
    @AppStorage("settings.appearance") private var appearanceRaw = Appearance.system.rawValue
    @AppStorage("settings.language") private var languageRaw = AppLanguage.system.rawValue

    var body: some View {
        NavigationStack {
            List {
                Section("settings.section.game") {
                    Toggle("settings.sound", isOn: $sound)
                    Toggle("settings.haptics", isOn: $haptics)
                }
                Section("settings.section.language") {
                    Picker("settings.language", selection: $languageRaw) {
                        Text("language.system").tag(AppLanguage.system.rawValue)
                        ForEach([AppLanguage.en, .fr, .es, .it, .de]) { language in
                            Text(language.nativeName).tag(language.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section("settings.section.appearance") {
                    Picker("settings.appearance", selection: $appearanceRaw) {
                        ForEach(Appearance.allCases) { option in
                            Text(LocalizedStringKey(option.localizationKey)).tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section {
                    NavigationLink("settings.licenses") { LicensesView() }
                }
            }
            .navigationTitle("nav.settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("nav.close") { model.send(.backToHub) }
                }
            }
        }
    }
}

struct LeaderboardView: View {
    @Environment(FlowModel.self) private var model
    let game: GameID?

    var body: some View {
        NavigationStack {
            List {
                ForEach(GameID.allCases, id: \.self) { game in
                    HStack {
                        Text(LocalizedStringKey(game.titleKey))
                        Spacer()
                        Text("\(model.flow.profiles.wins(.one, at: game)) – \(model.flow.profiles.wins(.two, at: game))")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(Theme.Umbrella.inkSecondary)
                    }
                }
            }
            .navigationTitle("nav.leaderboard")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("nav.close") { model.send(.backToHub) }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("leaderboard.gameCenter") { GameCenterLeaderboard.shared.showLeaderboards() }
                        .disabled(!GameCenterLeaderboard.shared.isAuthenticated)
                }
            }
        }
    }
}

// MARK: - Licences

struct LicensesView: View {
    var body: some View {
        List {
            Section("licenses.fonts") {
                LabeledContent("Zilla Slab", value: "SIL OFL 1.1")
                LabeledContent("Orbitron", value: "SIL OFL 1.1")
            }
            Section("licenses.sounds") {
                LabeledContent("Kenney", value: "CC0 1.0")
            }
            Section {
                Text("licenses.note")
                    .font(.footnote)
                    .foregroundStyle(Theme.Umbrella.inkSecondary)
            }
        }
        .navigationTitle("settings.licenses")
    }
}

// MARK: - Chantier

struct GamePlaceholderView: View {
    @Environment(FlowModel.self) private var model
    let game: GameID

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            Spacer()
            Text(LocalizedStringKey(game.titleKey))
                .font(Theme.Typo.display(36))
            Text("Interface en cours de construction.")
                .foregroundStyle(Theme.Umbrella.inkSecondary)
            Spacer()
            Button("game.quit") { model.send(.finishGame(.draw)) }
                .buttonStyle(SecondaryButtonStyle())
        }
        .padding(Theme.Space.l)
        .foregroundStyle(Theme.Umbrella.ink)
    }
}
