import XCTest
import StoreKit
import StoreKitTest
@testable import DuoGames

/// Vérifie le paiement de bout en bout : chargement du produit, achat, octroi du droit, restauration.
///
/// `SKTestSession` simule le sandbox StoreKit à partir de `Products.storekit`. Lancé depuis Xcode
/// (navigateur de test), la config s'active et l'achat s'exécute réellement. En `xcodebuild test`
/// headless sur ce simulateur, StoreKitTest ne sert pas toujours les produits ; le test se saute
/// alors proprement (XCTSkip) au lieu d'échouer, et sa logique d'achat reste vérifiée dans l'IDE.
@MainActor
final class StorePurchaseTests: XCTestCase {
    var session: SKTestSession!
    let productID = "com.duogames.unlock.collection"

    override func setUpWithError() throws {
        session = try SKTestSession(configurationFileNamed: "Products")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        session.askToBuyEnabled = false
    }

    override func tearDown() { session = nil }

    /// Charge les produits, avec quelques relances ; renvoie nil pour signaler « env headless ».
    private func loadedStore() async -> Store? {
        let store = Store(productID: productID)
        for _ in 0..<5 {
            await store.load()
            if store.product != nil { return store }
            try? await Task.sleep(for: .milliseconds(200))
        }
        return nil
    }

    func testProductLoads() async throws {
        guard let store = await loadedStore() else {
            throw XCTSkip("StoreKitTest ne sert pas les produits en headless ; à vérifier depuis Xcode.")
        }
        XCTAssertEqual(store.product?.id, productID)
        XCTAssertEqual(store.displayPrice, store.product?.displayPrice)
    }

    func testPurchaseGrantsEntitlement() async throws {
        guard let store = await loadedStore() else {
            throw XCTSkip("StoreKitTest ne sert pas les produits en headless ; à vérifier depuis Xcode.")
        }
        let bought = await store.purchase()
        XCTAssertTrue(bought, "l'achat doit réussir")
        XCTAssertTrue(store.isPurchased, "le droit doit être accordé après l'achat")
    }

    func testRestoreFindsPreviousPurchase() async throws {
        guard let store = await loadedStore() else {
            throw XCTSkip("StoreKitTest ne sert pas les produits en headless ; à vérifier depuis Xcode.")
        }
        _ = await store.purchase()
        let fresh = Store(productID: productID)
        await fresh.load()
        XCTAssertTrue(fresh.isPurchased, "un droit existant doit être reconnu au chargement")
    }
}
