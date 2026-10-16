import StoreKit
import Diagnostics

/// Achat unique non consommable qui débloque la collection. StoreKit 2, rien d'autre.
@MainActor
@Observable
final class Store {
    let productID: String
    private(set) var product: Product?
    private(set) var isPurchased = false
    private(set) var isLoading = false
    private var updates: Task<Void, Never>?

    init(productID: String) {
        self.productID = productID
        updates = Task { [weak self] in
            // Les transactions peuvent arriver hors de l'app : remboursement, achat sur un autre appareil.
            for await result in Transaction.updates {
                guard let self, case .verified(let transaction) = result else { continue }
                await self.apply(transaction)
                await transaction.finish()
            }
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            product = try await Product.products(for: [productID]).first
            await refreshEntitlement()
        } catch {
            DiagnosticsCenter.shared.record(.error, category: "storekit", "Chargement produit : \(error.localizedDescription)")
        }
    }

    /// Renvoie `true` si l'achat est effectif et vérifié.
    func purchase() async -> Bool {
        guard let product else { return false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    DiagnosticsCenter.shared.record(.error, category: "storekit", "Transaction non vérifiée")
                    return false
                }
                await apply(transaction)
                await transaction.finish()
                return isPurchased
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            DiagnosticsCenter.shared.record(.error, category: "storekit", "Achat : \(error.localizedDescription)")
            return false
        }
    }

    func restore() async -> Bool {
        do {
            try await AppStore.sync()
        } catch {
            DiagnosticsCenter.shared.record(.warning, category: "storekit", "Restauration : \(error.localizedDescription)")
        }
        await refreshEntitlement()
        return isPurchased
    }

    private func refreshEntitlement() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == productID,
               transaction.revocationDate == nil {
                isPurchased = true
                return
            }
        }
        isPurchased = false
    }

    private func apply(_ transaction: Transaction) async {
        guard transaction.productID == productID else { return }
        isPurchased = transaction.revocationDate == nil
    }

    var displayPrice: String { product?.displayPrice ?? "—" }
}
