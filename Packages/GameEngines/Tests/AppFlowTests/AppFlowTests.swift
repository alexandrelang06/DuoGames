import Testing
@testable import AppFlow

@Suite("Parcours de l'app")
struct AppFlowTests {

    @Test("Au premier lancement, l'onboarding s'ouvre")
    func firstLaunchShowsOnboarding() {
        let flow = AppFlow()
        #expect(flow.screen == .onboarding(step: 0))
    }

    @Test("Au lancement suivant, on arrive directement au hub")
    func returningLaunchGoesToHub() {
        let flow = AppFlow(progress: FlowProgress(onboardingCompleted: true))
        #expect(flow.screen == .hub)
    }

    @Test("L'onboarding fait trois écrans puis rend la main")
    func onboardingHasThreeSteps() {
        var flow = AppFlow()
        flow.handle(.advanceOnboarding)
        #expect(flow.screen == .onboarding(step: 1))
        flow.handle(.advanceOnboarding)
        #expect(flow.screen == .onboarding(step: 2))
        flow.handle(.advanceOnboarding)
        #expect(flow.screen == .hub)
        #expect(flow.progress.onboardingCompleted)
    }

    @Test("L'onboarding est passable à tout moment")
    func onboardingIsSkippable() {
        var flow = AppFlow()
        flow.handle(.skipOnboarding)
        #expect(flow.screen == .hub)
        #expect(flow.progress.onboardingCompleted)
    }

    @Test("Un jeu gratuit passe par son tutoriel la première fois")
    func freeGameShowsTutorialOnce() {
        var flow = AppFlow(progress: FlowProgress(onboardingCompleted: true))
        flow.handle(.selectGame(.airHockey))
        #expect(flow.screen == .tutorial(.airHockey))

        flow.handle(.dismissTutorial)
        #expect(flow.screen == .playing(.airHockey))
        #expect(flow.progress.tutorialsSeen.contains(.airHockey))
    }

    @Test("Le tutoriel vu n'est pas rejoué")
    func tutorialIsNotRepeated() {
        var flow = AppFlow(
            progress: FlowProgress(onboardingCompleted: true, tutorialsSeen: [.airHockey])
        )
        flow.handle(.selectGame(.airHockey))
        #expect(flow.screen == .playing(.airHockey))
    }

    @Test("Un appareil mal posé déclenche le guidage avant la partie")
    func unsuitablePostureShowsGuidance() {
        var flow = AppFlow(
            progress: FlowProgress(onboardingCompleted: true, tutorialsSeen: [.airHockey]),
            isPostureReady: false
        )
        flow.handle(.selectGame(.airHockey))
        #expect(flow.screen == .postureGuidance(.airHockey))

        flow.handle(.postureBecameReady)
        #expect(flow.screen == .playing(.airHockey))
    }

    @Test("Soulever l'appareil en pleine partie ramène au guidage")
    func liftingDeviceInterruptsPlay() {
        var flow = AppFlow(progress: FlowProgress(onboardingCompleted: true, tutorialsSeen: [.airHockey]))
        flow.handle(.selectGame(.airHockey))
        #expect(flow.screen == .playing(.airHockey))

        flow.handle(.postureBecameUnsuitable)
        #expect(flow.screen == .postureGuidance(.airHockey))
    }

    @Test("Le guidage n'interrompt rien en dehors d'une partie")
    func postureDoesNotInterruptMenus() {
        var flow = AppFlow(progress: FlowProgress(onboardingCompleted: true))
        flow.handle(.openProfile)
        flow.handle(.postureBecameUnsuitable)
        #expect(flow.screen == .profile, "on ne chasse pas le joueur hors des menus")
    }

    @Test("Une fin de partie est enregistrée dans l'historique")
    func finishingGameRecordsDuel() {
        var flow = AppFlow(progress: FlowProgress(onboardingCompleted: true, tutorialsSeen: [.airHockey]))
        flow.handle(.selectGame(.airHockey))
        flow.handle(.finishGame(.winner(.one)))

        #expect(flow.screen == .gameOver(.airHockey, .winner(.one)))
        #expect(flow.profiles.wins(.one) == 1)
        #expect(flow.profiles.recentDuels.first?.game == .airHockey)
    }

    @Test("La revanche relance immédiatement le même jeu")
    func rematchRestartsSameGame() {
        var flow = AppFlow(progress: FlowProgress(onboardingCompleted: true, tutorialsSeen: [.airHockey]))
        flow.handle(.selectGame(.airHockey))
        flow.handle(.finishGame(.draw))
        flow.handle(.rematch)
        #expect(flow.screen == .playing(.airHockey), "pas de tutoriel, pas de détour")
    }
}

@Suite("Déblocage")
struct UnlockFlowTests {

    private func playedOnce() -> AppFlow {
        var flow = AppFlow(progress: FlowProgress(onboardingCompleted: true, tutorialsSeen: [.airHockey]))
        flow.handle(.selectGame(.airHockey))
        flow.handle(.finishGame(.winner(.one)))
        return flow
    }

    @Test("Le jeu offert est jouable, les autres sont verrouillés")
    func defaultCatalog() {
        let flow = AppFlow(progress: FlowProgress(onboardingCompleted: true))
        #expect(flow.isUnlocked(.airHockey))
        #expect(flow.isUnlocked(.chess) == false)
        #expect(flow.hasLockedGames)
    }

    @Test("Toucher un jeu verrouillé ouvre l'écran de déblocage")
    func lockedGameOpensUnlock() {
        var flow = AppFlow(progress: FlowProgress(onboardingCompleted: true))
        flow.handle(.selectGame(.chess))
        #expect(flow.screen == .unlock(.lockedGame(.chess)))
    }

    @Test("L'achat débloque et renvoie au hub")
    func purchaseUnlocksAndReturnsToHub() {
        var flow = AppFlow(progress: FlowProgress(onboardingCompleted: true))
        flow.handle(.selectGame(.chess))
        flow.handle(.purchaseSucceeded)

        #expect(flow.isUnlocked(.chess))
        #expect(flow.screen == .hub, "après l'achat, le joueur choisit son jeu depuis le hub")
        #expect(flow.hasLockedGames == false)
    }

    @Test("Un achat annulé ramène au hub sans rien débloquer")
    func cancelledPurchaseReturnsToHub() {
        var flow = AppFlow(progress: FlowProgress(onboardingCompleted: true))
        flow.handle(.selectGame(.chess))
        flow.handle(.purchaseCancelled)
        #expect(flow.screen == .hub)
        #expect(flow.isUnlocked(.chess) == false)
    }

    @Test("La restauration débloque aussi")
    func restoreUnlocks() {
        var flow = AppFlow(progress: FlowProgress(onboardingCompleted: true))
        flow.handle(.restoreSucceeded)
        #expect(flow.isUnlocked(.tron))
    }

    @Test("Le déblocage n'est proposé qu'après une partie terminée")
    func unlockProposedAfterVictory() {
        var flow = playedOnce()
        flow.handle(.backToHub)
        #expect(flow.screen == .unlock(.afterVictory(.airHockey)),
                "sur un moment de joie, jamais avant")
    }

    @Test("La proposition n'apparaît qu'une fois par session")
    func unlockIsNotNagging() {
        var flow = playedOnce()
        flow.handle(.backToHub)              // proposition
        flow.handle(.purchaseCancelled)      // refus

        flow.handle(.selectGame(.airHockey))
        flow.handle(.finishGame(.winner(.two)))
        flow.handle(.backToHub)
        #expect(flow.screen == .hub, "on ne redemande pas dans la même session")
    }

    @Test("Rien n'est proposé si tout est déjà acquis")
    func noPromptWhenEverythingOwned() {
        var flow = AppFlow(
            progress: FlowProgress(onboardingCompleted: true, tutorialsSeen: [.airHockey]),
            entitlements: Entitlements(hasCollection: true)
        )
        flow.handle(.selectGame(.airHockey))
        flow.handle(.finishGame(.winner(.one)))
        flow.handle(.backToHub)
        #expect(flow.screen == .hub)
    }
}

@Suite("Accès rapide au jeu")
struct TimeToPlayTests {

    @Test("Trois intentions suffisent pour jouer au premier lancement")
    func shortestPathFromFirstLaunch() {
        // PRD §10.7 : moins de 30 secondes entre le lancement et le premier coup.
        var flow = AppFlow()
        var steps = 0

        flow.handle(.skipOnboarding);            steps += 1
        flow.handle(.selectGame(.airHockey));    steps += 1
        flow.handle(.dismissTutorial);           steps += 1

        #expect(flow.screen == .playing(.airHockey))
        #expect(steps == 3, "le chemin le plus court doit rester très court")
    }

    @Test("Une seule intention suffit au joueur habitué")
    func shortestPathForReturningPlayer() {
        var flow = AppFlow(
            progress: FlowProgress(onboardingCompleted: true, tutorialsSeen: Set(GameID.allCases))
        )
        flow.handle(.selectGame(.airHockey))
        #expect(flow.screen == .playing(.airHockey))
    }
}
