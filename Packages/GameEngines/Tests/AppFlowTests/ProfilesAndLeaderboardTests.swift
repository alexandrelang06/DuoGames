import Testing
@testable import AppFlow

@Suite("Espace joueur local")
struct PlayerProfilesTests {

    @Test("Deux places, vides au départ")
    func startsEmpty() {
        let profiles = PlayerProfiles()
        #expect(profiles.profile(.one).name.isEmpty)
        #expect(profiles.history.isEmpty)
        #expect(profiles.wins(.one) == 0)
    }

    @Test("Le prénom est nettoyé et borné")
    func nameIsTrimmedAndCapped() {
        var profiles = PlayerProfiles()
        profiles.rename(.one, to: "   Alex   ")
        #expect(profiles.profile(.one).name == "Alex")

        profiles.rename(.two, to: String(repeating: "a", count: 40))
        #expect(profiles.profile(.two).name.count == 16, "on ne casse pas la mise en page")
    }

    @Test("Les victoires se comptent par joueur et par jeu")
    func winsAreCounted() {
        var profiles = PlayerProfiles()
        profiles.record(Duel(game: .airHockey, result: .winner(.one)))
        profiles.record(Duel(game: .chess, result: .winner(.one)))
        profiles.record(Duel(game: .chess, result: .winner(.two)))
        profiles.record(Duel(game: .mill, result: .draw))

        #expect(profiles.wins(.one) == 2)
        #expect(profiles.wins(.two) == 1)
        #expect(profiles.draws() == 1)
        #expect(profiles.wins(.one, at: .chess) == 1)
        #expect(profiles.wins(.one, at: .tron) == 0)
    }

    @Test("L'historique reste borné sur l'appareil")
    func historyIsBounded() {
        var profiles = PlayerProfiles(historyLimit: 3)
        for _ in 0..<10 {
            profiles.record(Duel(game: .tron, result: .winner(.one)))
        }
        #expect(profiles.history.count == 3)
    }

    @Test("Les duels récents s'affichent du plus récent au plus ancien")
    func recentDuelsAreReversed() {
        var profiles = PlayerProfiles()
        profiles.record(Duel(game: .airHockey, result: .winner(.one)))
        profiles.record(Duel(game: .chess, result: .draw))
        #expect(profiles.recentDuels.first?.game == .chess)
    }

    @Test("La mise à jour des profils ne change pas l'écran")
    func updateProfilesKeepsScreen() {
        var flow = AppFlow(progress: FlowProgress(onboardingCompleted: true))
        var profiles = flow.profiles
        profiles.rename(.one, to: "Alex")
        flow.updateProfiles(profiles)
        #expect(flow.screen == .hub)
        #expect(flow.profiles.profile(.one).name == "Alex")
    }

    @Test("Le match nul n'a pas de vainqueur")
    func drawHasNoWinner() {
        #expect(MatchResult.draw.winner == nil)
        #expect(MatchResult.winner(.two).winner == .two)
    }
}

@Suite("Classement")
struct LeaderboardTests {

    @Test("Chaque jeu a son identifiant de classement")
    func leaderboardIdentifiers() {
        #expect(LeaderboardID.wins(.chess).rawValue == "com.duogames.leaderboard.chess.wins")
        #expect(LeaderboardID.wins(.tron) != LeaderboardID.wins(.mill))
    }

    @Test("Les scores soumis sont retenus")
    func submissionsAreRecorded() async throws {
        let leaderboard = LocalLeaderboard()
        try await leaderboard.submit(score: 3, to: .wins(.chess))
        try await leaderboard.submit(score: 5, to: .wins(.chess))

        let scores = await leaderboard.scores(for: .wins(.chess))
        #expect(scores == [3, 5])
    }

    @Test("L'indisponibilité du classement est détectable")
    func availabilityIsReported() async {
        let offline = LocalLeaderboard(available: false)
        let available = await offline.isAvailable()
        #expect(available == false)
    }
}

@Suite("Catalogue")
struct CatalogTests {

    @Test("Un jeu offert, le reste dans la collection payante")
    func defaultCatalogSplit() {
        let catalog = Catalog.default
        #expect(catalog.freeGames == [.airHockey])
        #expect(Set(catalog.paidGames) == Set([.chess, .draughts, .tron, .mill]))
    }

    @Test("Les jeux temps réel sont identifiés")
    func realTimeGames() {
        #expect(GameID.airHockey.isRealTime)
        #expect(GameID.tron.isRealTime)
        #expect(GameID.chess.isRealTime == false)
        #expect(GameID.draughts.isRealTime == false)
        #expect(GameID.mill.isRealTime == false)
    }

    @Test("L'achat débloque tous les jeux payants")
    func collectionUnlocksEverything() {
        var entitlements = Entitlements()
        #expect(entitlements.isUnlocked(.chess, in: .default) == false)
        entitlements.grantCollection()
        #expect(GameID.allCases.allSatisfy { entitlements.isUnlocked($0, in: .default) })
    }
}
