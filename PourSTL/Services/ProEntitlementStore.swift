import StoreKit
import UIKit

/// StoreKit requests never block the free offline tools. Verified transactions
/// unlock immediately; entitlement refreshes reconcile the App Store history.
@MainActor
@Observable
final class ProEntitlementStore {
    private(set) var products: [Product] = []
    private(set) var productsState: ProProductsState = .idle
    private(set) var purchaseStatus: ProPurchaseStatus = .idle
    private(set) var restoreStatus: ProRestoreStatus = .idle
    private(set) var hasResolvedEntitlements = false
    private(set) var isObservingTransactions = false
    private(set) var notice: String?

    var activeProductIDs: Set<String> {
        // An expiry wakes observers even when StoreKit sends no new transaction.
        _ = entitlementRevision
        return ProEntitlementDecision.activeProductIDs(
            in: entitlementSnapshots, knownProductIDs: ProProductID.all, now: now()
        )
    }

    var isPro: Bool { !activeProductIDs.isEmpty }

    var offers: [ProProductOffer] {
        products.map { product in
            ProProductOffer(id: product.id, title: ProProductFormatting.offerTitle(for: product))
        }
    }

    private var entitlementSnapshots: [ProTransactionSnapshot] = []
    private var entitlementRevision = 0
    // Keep a directly verified transaction until currentEntitlements catches up.
    private var unreconciledTransactions: [String: ProTransactionSnapshot] = [:]
    private var updatesTask: Task<Void, Never>?
    private var expirationTask: Task<Void, Never>?
    private var hasStarted = false
    private var listenerGeneration = 0
    private var refreshGeneration = 0
    private var operationInProgress = false
    private let now: () -> Date
    private let loadEntitlements: () async -> [ProTransactionSnapshot]
    private let restorePurchases: () async throws -> Void
    private let observesTransactionUpdates: Bool

    init(
        now: @escaping () -> Date = Date.init,
        loadEntitlements: (() async -> [ProTransactionSnapshot])? = nil,
        restorePurchases: (() async throws -> Void)? = nil,
        observesTransactionUpdates: Bool = true
    ) {
        self.now = now
        self.loadEntitlements = loadEntitlements ?? { await Self.currentEntitlements() }
        self.restorePurchases = restorePurchases ?? { try await AppStore.sync() }
        self.observesTransactionUpdates = observesTransactionUpdates
    }

    /// UI navigation tests use an explicitly free account. Their app process
    /// must not inherit receipts from StoreKit unit tests on the same simulator.
    /// Release always uses the real App Store, regardless of launch arguments.
    static func forAppLaunch(uiTesting: Bool) -> ProEntitlementStore {
        #if DEBUG
        if uiTesting {
            return ProEntitlementStore(
                loadEntitlements: { [] }, restorePurchases: {},
                observesTransactionUpdates: false
            )
        }
        #endif
        return ProEntitlementStore()
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        if observesTransactionUpdates {
            listenerGeneration += 1
            let generation = listenerGeneration
            // Do not return from start() while the listener task is merely
            // scheduled: a purchase could otherwise precede its subscription.
            await withCheckedContinuation { ready in
                updatesTask = Task { [weak self] in
                    guard let self else { ready.resume(); return }
                    await self.observeTransactions(ready: ready, generation: generation)
                }
            }
        }
        guard hasStarted else { return }
        await refreshEntitlements()
    }

    func stop() {
        updatesTask?.cancel()
        updatesTask = nil
        listenerGeneration += 1
        isObservingTransactions = false
        expirationTask?.cancel()
        expirationTask = nil
        refreshGeneration += 1
        hasStarted = false
    }

    func loadProducts() async {
        guard productsState != .loading else { return }
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
        guard !operationInProgress else { return }
        guard let product = products.first(where: { $0.id == productID }) else {
            purchaseStatus = .failed(ProStoreCopy.productMissing)
            Haptics.error()
            return
        }
        var transactionToFinish: Transaction?
        await performPurchase {
            switch try await product.purchase() {
            case .success(let verification):
                guard let transaction = Self.verifiedTransaction(verification) else {
                    return .unverified
                }
                transactionToFinish = transaction
                return .verified(Self.snapshot(transaction))
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .unexpected
            }
        }
        // Access is applied before finishing or awaiting another StoreKit query.
        await transactionToFinish?.finish()
    }

    /// The StoreKit adapter above supplies verified outcomes. Tests inject the
    /// same outcomes to cover successful, pending and failed purchase behavior.
    func performPurchase(_ purchase: () async throws -> ProPurchaseOutcome) async {
        guard !operationInProgress else { return }
        operationInProgress = true
        defer { operationInProgress = false }
        purchaseStatus = .inProgress
        restoreStatus = .idle
        notice = nil
        do {
            switch try await purchase() {
            case .verified(let transaction):
                applyVerifiedTransaction(transaction)
                let unlocks = ProEntitlementDecision.isActive(
                    transaction, knownProductIDs: ProProductID.all, now: now()
                ) && activeProductIDs.contains(transaction.productID)
                purchaseStatus = ProPurchaseInterpreter.successStatus(verified: true, unlocksPro: unlocks)
                if unlocks { Haptics.success() } else { Haptics.error() }
            case .unverified:
                purchaseStatus = .failed(ProStoreCopy.unverified)
                Haptics.error()
            case .pending:
                // Approval can arrive through Transaction.updates while the
                // purchase sheet is returning its pending result.
                purchaseStatus = isPro ? .succeeded : .pending
                if !isPro { Haptics.warning() }
            case .cancelled:
                purchaseStatus = .cancelled
            case .unexpected:
                purchaseStatus = .failed(ProStoreCopy.unexpected)
                Haptics.error()
            }
        } catch {
            purchaseStatus = .failed(ProStoreCopy.purchaseFailed)
            Haptics.error()
        }
    }

    func restore() async {
        guard !operationInProgress else { return }
        operationInProgress = true
        defer { operationInProgress = false }
        restoreStatus = .inProgress
        purchaseStatus = .idle
        notice = nil
        do {
            try await restorePurchases()
            await refreshEntitlements()
            restoreStatus = ProRestoreInterpreter.status(isPro: isPro)
            if isPro { Haptics.success() }
        } catch {
            restoreStatus = .failed(ProStoreCopy.restoreFailed)
            Haptics.error()
        }
    }

    func resetTransientStatus() {
        guard !operationInProgress else { return }
        // An approval request remains pending until StoreKit resolves it.
        if purchaseStatus != .pending { purchaseStatus = .idle }
        restoreStatus = .idle
        notice = nil
    }

    func manageSubscriptions() async {
        guard !operationInProgress else { return }
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
        var snapshots = await loadEntitlements()
        guard generation == refreshGeneration else { return }
        for (productID, pending) in unreconciledTransactions {
            let current = snapshots.filter { $0.productID == productID }
            if current.contains(where: { Self.reconciles($0, pending: pending) }) {
                unreconciledTransactions[productID] = nil
            } else {
                snapshots.removeAll { $0.productID == productID }
                snapshots.append(pending)
            }
        }
        entitlementSnapshots = snapshots
        hasResolvedEntitlements = true
        resolvePendingPurchase()
        scheduleExpiration()
    }

    /// Only call with the result of StoreKit verification. A late entitlement
    /// query must never overwrite a purchase or revocation received meanwhile.
    func applyVerifiedTransaction(_ transaction: ProTransactionSnapshot) {
        guard ProProductID.all.contains(transaction.productID) else { return }
        if let current = entitlementSnapshots.first(where: {
            $0.productID == transaction.productID && $0.transactionID != nil && $0.transactionID == transaction.transactionID
        }) {
            if current.revocationDate != nil, transaction.revocationDate == nil { return }
            if current.isUpgraded, !transaction.isUpgraded { return }
        }
        if let newer = entitlementSnapshots.first(where: {
            $0.productID == transaction.productID && Self.isNewer($0, than: transaction)
        }), newer.transactionID != transaction.transactionID { return }
        refreshGeneration += 1
        unreconciledTransactions[transaction.productID] = transaction
        entitlementSnapshots.removeAll { $0.productID == transaction.productID }
        entitlementSnapshots.append(transaction)
        hasResolvedEntitlements = true
        resolvePendingPurchase()
        scheduleExpiration()
    }

    private func resolvePendingPurchase() {
        if purchaseStatus == .pending, isPro {
            purchaseStatus = .succeeded
            Haptics.success()
        }
        if !isPro {
            if purchaseStatus == .succeeded { purchaseStatus = .idle }
            if restoreStatus == .restored { restoreStatus = .idle }
        }
    }

    private func scheduleExpiration() {
        expirationTask?.cancel()
        let currentDate = now()
        guard let expiration = entitlementSnapshots.compactMap({ transaction -> Date? in
            guard ProEntitlementDecision.isActive(transaction, knownProductIDs: ProProductID.all, now: currentDate) else { return nil }
            return transaction.expirationDate
        }).min() else {
            expirationTask = nil
            return
        }
        let delay = max(0, expiration.timeIntervalSince(currentDate))
        expirationTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            guard let self, !Task.isCancelled else { return }
            self.entitlementRevision += 1
            await self.refreshEntitlements()
        }
    }

    private func observeTransactions(ready: CheckedContinuation<Void, Never>, generation: Int) async {
        var iterator = Transaction.updates.makeAsyncIterator()
        guard !Task.isCancelled, generation == listenerGeneration else {
            ready.resume()
            return
        }
        isObservingTransactions = true
        ready.resume()
        defer {
            if generation == listenerGeneration { isObservingTransactions = false }
        }
        while let update = await iterator.next() {
            guard !Task.isCancelled, generation == listenerGeneration else { return }
            guard let transaction = Self.verifiedTransaction(update) else { continue }
            applyVerifiedTransaction(Self.snapshot(transaction))
            await transaction.finish()
            await refreshEntitlements()
        }
    }

    private static func currentEntitlements() async -> [ProTransactionSnapshot] {
        var snapshots: [ProTransactionSnapshot] = []
        for await result in Transaction.currentEntitlements {
            guard let transaction = verifiedTransaction(result) else { continue }
            snapshots.append(snapshot(transaction))
        }
        return snapshots
    }

    private static func snapshot(_ transaction: Transaction) -> ProTransactionSnapshot {
        ProTransactionSnapshot(
            productID: transaction.productID,
            revocationDate: transaction.revocationDate,
            expirationDate: transaction.expirationDate,
            transactionID: transaction.id,
            purchaseDate: transaction.purchaseDate,
            isUpgraded: transaction.isUpgraded
        )
    }

    private static func isNewer(_ current: ProTransactionSnapshot, than pending: ProTransactionSnapshot) -> Bool {
        guard let currentDate = current.purchaseDate, let pendingDate = pending.purchaseDate else { return false }
        return currentDate > pendingDate
    }

    private static func reconciles(_ current: ProTransactionSnapshot, pending: ProTransactionSnapshot) -> Bool {
        if isNewer(current, than: pending) { return true }
        guard let transactionID = pending.transactionID, current.transactionID == transactionID else {
            return current == pending
        }
        // Do not undo a revocation or upgrade with a stale copy of the same ID.
        if pending.revocationDate != nil, current.revocationDate == nil { return false }
        if pending.isUpgraded, !current.isUpgraded { return false }
        return true
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
