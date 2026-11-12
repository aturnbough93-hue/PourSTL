import StoreKit
import UIKit

/// StoreKit 2 purchase, restore, and entitlement state for Pour Pro.
/// Launch listens for transaction updates and reads current entitlements.
/// Product requests happen when the upsell opens, so a missing network
/// does not block the free offline tools.
@MainActor
@Observable
final class ProEntitlementStore {
    private(set) var products: [Product] = []
    private(set) var activeProductIDs: Set<String> = []
    private(set) var productsState: ProProductsState = .idle
    private(set) var purchaseStatus: ProPurchaseStatus = .idle
    private(set) var restoreStatus: ProRestoreStatus = .idle
    private(set) var hasResolvedEntitlements = false
    private(set) var notice: String?

    var isPro: Bool { !activeProductIDs.isEmpty }

    var offers: [ProProductOffer] {
        products.map { product in
            ProProductOffer(id: product.id, title: ProProductFormatting.offerTitle(for: product))
        }
    }

    private var updatesTask: Task<Void, Never>?
    private var hasStarted = false
    private var refreshGeneration = 0

    /// Begins `Transaction.updates` and checks `Transaction.currentEntitlements`.
    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        updatesTask = Task { [weak self] in
            await self?.observeTransactions()
        }
        await refreshEntitlements()
        hasResolvedEntitlements = true
    }

    func stop() {
        updatesTask?.cancel()
        updatesTask = nil
        hasStarted = false
    }

    func loadProducts() async {
        productsState = .loading
        do {
            let loaded = try await Product.products(for: ProProductID.ordered)
            products = Self.sorted(loaded)
            productsState = products.isEmpty ? .unavailable : .loaded
        } catch {
            products = []
            productsState = .unavailable
        }
    }

    func purchase(productID: String) async {
        guard let product = products.first(where: { $0.id == productID }) else {
            purchaseStatus = .failed(ProStoreCopy.productMissing)
            Haptics.error()
            return
        }
        await purchase(product)
    }

    func restore() async {
        restoreStatus = .inProgress
        notice = nil
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            restoreStatus = ProRestoreInterpreter.status(isPro: isPro)
            if isPro { Haptics.success() }
        } catch {
            restoreStatus = .failed(ProStoreCopy.restoreFailed)
            Haptics.error()
        }
    }

    func manageSubscriptions() async {
        guard let scene = Self.foregroundScene() else {
            notice = ProStoreCopy.manageUnavailable
            return
        }
        do {
            try await AppStore.showManageSubscriptions(in: scene)
            notice = nil
            await refreshEntitlements()
        } catch {
            notice = ProStoreCopy.manageFailed
        }
    }

    func refreshEntitlements() async {
        refreshGeneration += 1
        let generation = refreshGeneration
        var snapshots: [ProTransactionSnapshot] = []
        for await result in Transaction.currentEntitlements {
            guard let transaction = Self.verifiedTransaction(result) else { continue }
            snapshots.append(ProTransactionSnapshot(
                productID: transaction.productID,
                revocationDate: transaction.revocationDate,
                expirationDate: transaction.expirationDate
            ))
        }
        guard generation == refreshGeneration else { return }
        activeProductIDs = ProEntitlementDecision.activeProductIDs(
            in: snapshots,
            knownProductIDs: ProProductID.all,
            now: Date()
        )
    }

    private func purchase(_ product: Product) async {
        purchaseStatus = .inProgress
        notice = nil
        do {
            let result = try await product.purchase()
            if let immediate = ProPurchaseInterpreter.status(for: result) {
                purchaseStatus = immediate
                if immediate == .pending { Haptics.warning() }
                return
            }
            guard case .success(let verification) = result else {
                purchaseStatus = .failed(ProStoreCopy.unexpected)
                return
            }
            guard let transaction = Self.verifiedTransaction(verification) else {
                purchaseStatus = ProPurchaseInterpreter.successStatus(verified: false, unlocksPro: false)
                Haptics.error()
                return
            }
            await transaction.finish()
            await refreshEntitlements()
            let status = ProPurchaseInterpreter.successStatus(
                verified: true,
                unlocksPro: activeProductIDs.contains(transaction.productID)
            )
            purchaseStatus = status
            if status == .succeeded {
                Haptics.success()
            } else {
                Haptics.error()
            }
        } catch {
            purchaseStatus = .failed(ProStoreCopy.purchaseFailed)
            Haptics.error()
        }
    }

    private func observeTransactions() async {
        for await update in Transaction.updates {
            if Task.isCancelled { return }
            await handle(update)
        }
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard let transaction = Self.verifiedTransaction(result) else { return }
        await transaction.finish()
        await refreshEntitlements()
    }

    static func verifiedTransaction<T>(_ result: VerificationResult<T>) -> T? {
        guard case .verified(let value) = result else { return nil }
        return value
    }

    private static func sorted(_ products: [Product]) -> [Product] {
        let order = ProProductID.ordered
        return products.sorted { lhs, rhs in
            let left = order.firstIndex(of: lhs.id) ?? order.count
            let right = order.firstIndex(of: rhs.id) ?? order.count
            if left == right { return lhs.id < rhs.id }
            return left < right
        }
    }

    private static func foregroundScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }
}
