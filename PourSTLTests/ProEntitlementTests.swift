import StoreKit
import StoreKitTest
import XCTest
@testable import PourSTL

final class ProEntitlementLogicTests: XCTestCase {

    func testProductIDsStayInOneList() {
        XCTAssertEqual(ProProductID.ordered, [
            "com.pourstl.app.pro.monthly",
            "com.pourstl.app.pro.yearly",
        ])
        XCTAssertEqual(ProProductID.all, Set(ProProductID.ordered))
        XCTAssertEqual(ProProductID.privacyPolicyURL.absoluteString, "https://pourstl.com/privacy")
        XCTAssertEqual(
            ProProductID.termsOfUseURL.absoluteString,
            "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
        )
    }

    func testStoreKitFileMatchesProductIDs() throws {
        let url = try XCTUnwrap(
            pourStoreKitURL(for: ProEntitlementLogicTests.self),
            "PourSTL.storekit must be copied into the app or test bundle"
        )
        let data = try Data(contentsOf: url)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let groups = try XCTUnwrap(json["subscriptionGroups"] as? [[String: Any]])
        var periods: [String: String] = [:]
        for group in groups {
            let subscriptions = try XCTUnwrap(group["subscriptions"] as? [[String: Any]])
            for subscription in subscriptions {
                let id = try XCTUnwrap(subscription["productID"] as? String)
                periods[id] = subscription["recurringSubscriptionPeriod"] as? String
            }
        }
        XCTAssertEqual(Set(periods.keys), ProProductID.all)
        XCTAssertEqual(periods[ProProductID.monthly], "P1M")
        XCTAssertEqual(periods[ProProductID.yearly], "P1Y")
    }

    func testRevokedTransactionIsNotEntitled() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = ProTransactionSnapshot(
            productID: ProProductID.monthly,
            revocationDate: now,
            expirationDate: now.addingTimeInterval(3_600)
        )
        XCTAssertFalse(ProEntitlementDecision.isActive(snapshot, knownProductIDs: ProProductID.all, now: now))
    }

    func testExpirationBoundaryIsNotEntitled() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let expired = ProTransactionSnapshot(
            productID: ProProductID.yearly,
            revocationDate: nil,
            expirationDate: now
        )
        let current = ProTransactionSnapshot(
            productID: ProProductID.monthly,
            revocationDate: nil,
            expirationDate: now.addingTimeInterval(1)
        )
        XCTAssertFalse(ProEntitlementDecision.isActive(expired, knownProductIDs: ProProductID.all, now: now))
        XCTAssertTrue(ProEntitlementDecision.isActive(current, knownProductIDs: ProProductID.all, now: now))
    }

    func testUnknownProductIsNotEntitled() {
        let snapshot = ProTransactionSnapshot(
            productID: "com.pourstl.app.pro.lifetime",
            revocationDate: nil,
            expirationDate: nil
        )
        XCTAssertFalse(ProEntitlementDecision.isActive(snapshot, knownProductIDs: ProProductID.all, now: Date()))
    }

    func testUpgradedTransactionIsNotEntitled() {
        let snapshot = ProTransactionSnapshot(
            productID: ProProductID.monthly,
            revocationDate: nil,
            expirationDate: Date().addingTimeInterval(3_600),
            isUpgraded: true
        )
        XCTAssertFalse(ProEntitlementDecision.isActive(snapshot, knownProductIDs: ProProductID.all, now: Date()))
    }

    func testMissingExpirationStaysActiveUntilRevoked() {
        let snapshot = ProTransactionSnapshot(
            productID: ProProductID.yearly,
            revocationDate: nil,
            expirationDate: nil
        )
        XCTAssertTrue(ProEntitlementDecision.isActive(snapshot, knownProductIDs: ProProductID.all, now: Date()))
    }

    func testActiveSetKeepsOnlyCurrentKnownProducts() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let ids = ProEntitlementDecision.activeProductIDs(in: [
            ProTransactionSnapshot(productID: ProProductID.monthly, revocationDate: nil, expirationDate: now.addingTimeInterval(100)),
            ProTransactionSnapshot(productID: ProProductID.yearly, revocationDate: now, expirationDate: nil),
            ProTransactionSnapshot(productID: "other", revocationDate: nil, expirationDate: nil),
        ], knownProductIDs: ProProductID.all, now: now)
        XCTAssertEqual(ids, [ProProductID.monthly])
    }

    func testNoTransactionsMeansNotPro() {
        let ids = ProEntitlementDecision.activeProductIDs(in: [], knownProductIDs: ProProductID.all, now: Date())
        XCTAssertTrue(ids.isEmpty)
    }

    func testFreeOfflineFeaturesAreNeverLocked() {
        XCTAssertTrue(ProGate.freeOffline.isDisjoint(with: ProGate.proPlaceholders))
        XCTAssertEqual(
            Set(PourCapability.allCases),
            ProGate.freeOffline.union(ProGate.proPlaceholders)
        )
        XCTAssertTrue(ProGate.freeOffline.contains(.barcodeScanner))
        XCTAssertTrue(ProGate.freeOffline.contains(.venueCheckIn))
        XCTAssertTrue(ProGate.freeOffline.contains(.aiAssistant))
        XCTAssertFalse(ProGate.proPlaceholders.contains(.barcodeScanner))
        XCTAssertFalse(ProGate.proPlaceholders.contains(.aiAssistant))
        XCTAssertFalse(ProGate.plannedFeatures.contains { $0.id == "assistant" })
        XCTAssertFalse(ProGate.placeholdersArePaywalled)
        for capability in PourCapability.allCases {
            XCTAssertFalse(ProGate.isLocked(capability, isPro: false), capability.rawValue)
            XCTAssertFalse(ProGate.isLocked(capability, isPro: true), capability.rawValue)
        }
    }

    func testPurchaseResultsMapToVisibleStates() {
        XCTAssertEqual(ProPurchaseInterpreter.status(for: .userCancelled), .cancelled)
        XCTAssertEqual(ProPurchaseInterpreter.status(for: .pending), .pending)
        XCTAssertEqual(
            ProPurchaseInterpreter.successStatus(verified: true, unlocksPro: true),
            .succeeded
        )
        XCTAssertEqual(
            ProPurchaseInterpreter.successStatus(verified: false, unlocksPro: true),
            .failed(ProStoreCopy.unverified)
        )
        XCTAssertEqual(
            ProPurchaseInterpreter.successStatus(verified: true, unlocksPro: false),
            .failed(ProStoreCopy.notIncluded)
        )
        XCTAssertEqual(ProPurchaseStatus.pending.message, ProStoreCopy.pending)
        XCTAssertEqual(ProPurchaseStatus.cancelled.message, ProStoreCopy.cancelled)
        XCTAssertEqual(ProPurchaseStatus.succeeded.announcement, ProStoreCopy.proActive)
        XCTAssertEqual(ProRestoreInterpreter.status(isPro: true), .restored)
        XCTAssertEqual(ProRestoreInterpreter.status(isPro: false), .nothingToRestore)
        XCTAssertEqual(ProRestoreStatus.nothingToRestore.message, ProStoreCopy.nothingToRestore)
        XCTAssertEqual(ProRestoreStatus.restored.announcement, ProStoreCopy.restored)
    }
}

@MainActor
final class ProEntitlementStoreTests: XCTestCase {
    private var session: SKTestSession!
    private var store: ProEntitlementStore!
    private var entitlementReader = StoreKitEntitlementReader()
    private static var sharedSession: SKTestSession?
    /// resetToDefaultState() closes an existing Transaction.updates sequence.
    /// Do that once, before the shared listener parks, and use clearTransactions
    /// afterwards so the listener stays attached for the rest of the process.
    private static var didResetSession = false
    /// storekitd syncs a newly installed app once before it answers the first
    /// entitlement query. On hosted runners that takes minutes, so it is paid
    /// here once instead of inside a test's own deadlines.
    private static var firstEntitlementSync = FirstEntitlementSync.notAttempted
    private static let firstEntitlementSyncLimit: TimeInterval = 600
    /// Set when the first sync or a start() did not finish. That failure is
    /// already recorded, and tearDown must not queue another read behind it.
    private var entitlementReadIsStuck = false

    private enum FirstEntitlementSync {
        case notAttempted, finished, didNotFinish
    }

    override func setUp() async throws {
        entitlementReader = StoreKitEntitlementReader()
        if Self.sharedSession == nil {
            let url = try XCTUnwrap(
                pourStoreKitURL(for: ProEntitlementStoreTests.self),
                "PourSTL.storekit must be copied into the app or test bundle"
            )
            Self.sharedSession = try SKTestSession(contentsOf: url)
        }
        session = Self.sharedSession
        if !Self.didResetSession {
            session.resetToDefaultState()
            Self.didResetSession = true
        }
        session.disableDialogs = true
        session.askToBuyEnabled = false
        // clearTransactions() is the test service. Do not call AppStore.sync()
        // here: sync() returns, then a StoreKit 2 entitlement read started
        // before the listener is parked never finishes.
        session.clearTransactions()
        XCTAssertTrue(
            session.allTransactions().isEmpty,
            "The StoreKit test service still contains transactions"
        )
        try await finishFirstEntitlementSync()
        store = ProEntitlementStore()
        try await start(store)
    }

    /// A sync that did not finish fails every later test at once. Nothing
    /// starts another read or store behind it.
    private func finishFirstEntitlementSync() async throws {
        switch Self.firstEntitlementSync {
        case .finished:
            return
        case .didNotFinish:
            entitlementReadIsStuck = true
            throw StoreKitFixtureFailure(
                "StoreKit's first entitlement sync did not finish in an earlier test, so this test did not start a store"
            )
        case .notAttempted:
            let started = Date()
            let first = await StoreKitEntitlementReader().read(
                timeoutNanoseconds: UInt64(Self.firstEntitlementSyncLimit * 1_000_000_000)
            ) {
                await Self.storeKitProductIDs()
            }
            print("StoreKit first entitlement sync took \(Int(Date().timeIntervalSince(started))) seconds")
            guard first != nil else {
                Self.firstEntitlementSync = .didNotFinish
                entitlementReadIsStuck = true
                throw StoreKitFixtureFailure(
                    "StoreKit's first entitlement sync did not finish within \(Int(Self.firstEntitlementSyncLimit)) seconds"
                )
            }
            Self.firstEntitlementSync = .finished
        }
    }

    /// start() reads currentEntitlements with no limit of its own. The task
    /// keeps the store alive if it returns late; the caller still stops it.
    private func start(_ store: ProEntitlementStore) async throws {
        let limit = StoreKitEntitlementReader.defaultTimeoutSeconds
        let finished: Bool? = await raceAgainstDeadline(nanoseconds: UInt64(limit) * 1_000_000_000) {
            await store.start()
            return true
        }
        guard finished != nil else {
            entitlementReadIsStuck = true
            throw StoreKitFixtureFailure("ProEntitlementStore.start() did not finish within \(limit) seconds")
        }
    }

    override func tearDown() async throws {
        // Read currentEntitlements on the main actor while the listener is
        // still attached. Stopping first leaves a cancelled consumer in next(),
        // and that is what wedged this read for the rest of the suite.
        defer {
            store?.stop()
            store = nil
            session = nil
        }
        guard let session else { return }
        session.disableDialogs = true
        session.askToBuyEnabled = false
        session.clearTransactions()
        XCTAssertTrue(
            session.allTransactions().isEmpty,
            "The StoreKit test service still contains transactions"
        )
        guard !entitlementReadIsStuck else { return }
        // A read that does not finish has already failed in the helper. It is
        // not evidence of a remaining product, and it is not an empty result.
        // remaining keeps the last set a read did return.
        var latest = await currentStoreKitProductIDs()
        var remaining = latest
        let deadline = Date().addingTimeInterval(TimeInterval(StoreKitEntitlementReader.defaultTimeoutSeconds))
        while let products = latest, !products.isEmpty, Date() < deadline {
            try? await Task.sleep(nanoseconds: 200_000_000)
            latest = await currentStoreKitProductIDs()
            if let latest { remaining = latest }
        }
        if let remaining {
            XCTAssertTrue(
                remaining.isEmpty,
                "The local StoreKit fixture did not clear its entitlements. Remaining verified products: \(remaining.sorted())"
            )
        }
    }

    func testLaunchWithoutPurchaseIsNotPro() {
        XCTAssertTrue(ProRuntime.isUnitTestHost)
        XCTAssertTrue(store.hasResolvedEntitlements)
        XCTAssertTrue(store.isObservingTransactions)
        XCTAssertFalse(store.isPro)
        XCTAssertTrue(store.activeProductIDs.isEmpty)
    }

    func testLoadsConfiguredProducts() async throws {
        await store.loadProducts()
        XCTAssertEqual(store.productsState, .loaded)
        XCTAssertEqual(store.offers.map(\.id), ProProductID.ordered)
        for offer in store.offers {
            XCTAssertFalse(offer.title.isEmpty)
            XCTAssertTrue(offer.title.contains(where: \.isNumber))
        }
    }

    func testTransactionUpdatesGrantEntitlement() async throws {
        XCTAssertFalse(store.isPro)
        XCTAssertTrue(store.isObservingTransactions, "start() must wait for the StoreKit listener")
        _ = try await session.buyProduct(identifier: ProProductID.yearly)
        let unlocked = await waitUntil { [store = self.store!] in
            store.isPro && store.activeProductIDs.contains(ProProductID.yearly)
        }
        let frameworkIDs = await currentStoreKitProductIDs() ?? []
        XCTAssertTrue(unlocked, "The ready StoreKit listener did not unlock. Current verified products: \(frameworkIDs.sorted()); store products: \(store.activeProductIDs.sorted()); listener active: \(store.isObservingTransactions)")
        XCTAssertTrue(store.activeProductIDs.contains(ProProductID.yearly))
    }

    func testUITestingStoreDoesNotInheritStoreKitTransactions() async throws {
        _ = try await session.buyProduct(identifier: ProProductID.yearly)
        let purchased = await waitUntil { [store = self.store!] in
            await store.refreshEntitlements()
            return store.isPro
        }
        XCTAssertTrue(purchased, "The real StoreKit fixture must contain a verified subscription")

        let uiStore = ProEntitlementStore.forAppLaunch(uiTesting: true)
        defer { uiStore.stop() }
        await uiStore.start()
        #if DEBUG
        XCTAssertTrue(uiStore.hasResolvedEntitlements)
        XCTAssertFalse(uiStore.isObservingTransactions)
        XCTAssertFalse(uiStore.isPro)
        await uiStore.refreshEntitlements()
        XCTAssertFalse(uiStore.isPro)
        #else
        // An explicit test argument cannot select a fake account in Release.
        XCTAssertTrue(uiStore.isObservingTransactions)
        XCTAssertTrue(uiStore.isPro)
        #endif
    }

    func testCurrentEntitlementsOnLaunch() async throws {
        _ = try await session.buyProduct(identifier: ProProductID.monthly)
        store.stop()
        let relaunched = ProEntitlementStore()
        defer { relaunched.stop() }
        try await start(relaunched)
        let unlocked = await waitUntil {
            if relaunched.isPro { return true }
            await relaunched.refreshEntitlements()
            return relaunched.isPro
        }
        XCTAssertTrue(unlocked)
        XCTAssertTrue(relaunched.hasResolvedEntitlements)
        XCTAssertTrue(relaunched.activeProductIDs.contains(ProProductID.monthly))
    }

    func testExpiredSubscriptionRemovesEntitlement() async throws {
        _ = try await session.buyProduct(identifier: ProProductID.monthly)
        let unlocked = await waitUntil { [store = self.store!] in
            await store.refreshEntitlements()
            return store.isPro
        }
        XCTAssertTrue(unlocked)
        try session.expireSubscription(productIdentifier: ProProductID.monthly)
        let removed = await waitUntil { [store = self.store!] in
            await store.refreshEntitlements()
            return !store.isPro
        }
        if !removed {
            let frameworkIDs = await currentStoreKitProductIDs() ?? []
            XCTFail("Expired subscription stayed active. Current verified products: \(frameworkIDs.sorted()); store products: \(store.activeProductIDs.sorted())")
        }
        XCTAssertFalse(
            store.activeProductIDs.contains(ProProductID.monthly),
            "The monthly subscription must be removed after expiration"
        )
    }

    func testRestoreFindsExternalPurchase() async throws {
        _ = try await session.buyProduct(identifier: ProProductID.yearly)
        let present = await waitUntil { [store = self.store!] in
            await store.refreshEntitlements()
            return store.isPro
        }
        XCTAssertTrue(present)
        await store.restore()
        XCTAssertEqual(store.restoreStatus, .restored)
        XCTAssertTrue(store.isPro)
    }

    func testRestoreWithNoSubscription() async throws {
        await store.restore()
        XCTAssertEqual(store.restoreStatus, .nothingToRestore)
        XCTAssertFalse(store.isPro)
    }

    func testMissingProductDoesNotGrantEntitlement() async {
        await store.purchase(productID: ProProductID.monthly)
        XCTAssertEqual(store.purchaseStatus, .failed(ProStoreCopy.productMissing))
        XCTAssertFalse(store.isPro)
    }

    /// The condition races the deadline, so one call that never returns
    /// cannot hold the test past its timeout. It may still return after
    /// tearDown, so a condition must capture the store, not read self.store.
    /// The deadline cuts a condition off mid-read, so it has to leave room
    /// for several reads.
    private func waitUntil(
        timeout: TimeInterval = TimeInterval(StoreKitEntitlementReader.defaultTimeoutSeconds),
        _ condition: @escaping @MainActor () async -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        let met = await raceAgainstDeadline(nanoseconds: UInt64(timeout * 1_000_000_000)) { @MainActor in
            while !Task.isCancelled {
                if await condition() { return true }
                guard Date() < deadline else { break }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            return false
        }
        return met ?? false
    }

    /// nil means the read did not finish. That failure is recorded once here.
    private func currentStoreKitProductIDs() async -> Set<String>? {
        let hadTimedOut = entitlementReader.didTimeOut
        let ids = await entitlementReader.read {
            await Self.storeKitProductIDs()
        }
        if ids == nil, !hadTimedOut {
            XCTFail("Transaction.currentEntitlements did not finish within \(StoreKitEntitlementReader.defaultTimeoutSeconds) seconds in this test's StoreKit fixture")
        }
        return ids
    }

    private static func storeKitProductIDs() async -> Set<String> {
        var ids: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  ProProductID.all.contains(transaction.productID) else { continue }
            ids.insert(transaction.productID)
        }
        return ids
    }
}

/// Unstructured tasks let the caller stop waiting even if the operation
/// ignores cancellation. nil means the deadline came first.
@MainActor
private func raceAgainstDeadline<Value: Sendable>(
    nanoseconds: UInt64,
    operation: @escaping @MainActor () async -> Value
) async -> Value? {
    var operationTask: Task<Void, Never>?
    var deadlineTask: Task<Void, Never>?
    let value: Value? = await withCheckedContinuation { continuation in
        let gate = DeadlineGate(continuation)
        operationTask = Task { @MainActor in
            gate.finish(await operation())
        }
        deadlineTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: nanoseconds)
            } catch {
                return
            }
            gate.finish(nil)
        }
    }
    operationTask?.cancel()
    deadlineTask?.cancel()
    return value
}

@MainActor
private final class StoreKitEntitlementReader {
    /// A stall detector, not a timing assertion. StoreKit syncs receipts
    /// with its test server on every read, and one read has taken 11.5
    /// seconds on a hosted runner, so 8 and 10 second limits failed there.
    nonisolated static let defaultTimeoutSeconds = 60
    /// Latched so one fixture never starts a second read behind a stuck one.
    private(set) var didTimeOut = false

    func read(
        timeoutNanoseconds: UInt64 = UInt64(defaultTimeoutSeconds) * 1_000_000_000,
        operation: @escaping @MainActor () async -> Set<String>
    ) async -> Set<String>? {
        guard !didTimeOut else { return nil }
        let ids = await raceAgainstDeadline(nanoseconds: timeoutNanoseconds, operation: operation)
        didTimeOut = ids == nil
        return ids
    }
}

private struct StoreKitFixtureFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

@MainActor
private final class DeadlineGate<Value> {
    private var continuation: CheckedContinuation<Value?, Never>?

    init(_ continuation: CheckedContinuation<Value?, Never>) {
        self.continuation = continuation
    }

    func finish(_ value: Value?) {
        let pending = continuation
        continuation = nil
        pending?.resume(returning: value)
    }
}

@MainActor
final class ProEntitlementReadTimeoutTests: XCTestCase {
    func testCompletedReadReturnsProducts() async {
        let products = await StoreKitEntitlementReader().read {
            [ProProductID.monthly]
        }
        XCTAssertEqual(products, [ProProductID.monthly])
    }

    func testTimeoutDoesNotPoisonTheNextFixtureOrAcceptLateResults() async {
        let pending = ProSuspendedOperation<Set<String>>()
        let reader = StoreKitEntitlementReader()
        let result = await reader.read(timeoutNanoseconds: 20_000_000) {
            await pending.run()
        }
        XCTAssertNil(result)
        pending.resume(returning: [ProProductID.yearly])
        let repeated = await reader.read { XCTFail("Must not start another wedged read"); return [] }
        XCTAssertNil(repeated)
        let nextFixture = await StoreKitEntitlementReader().read { [] }
        XCTAssertEqual(nextFixture, [])
    }
}

/// Exact outcomes and a controlled clock keep purchase regressions visible even
/// when CI cannot show a signed App Store purchase sheet.
@MainActor
final class ProPurchaseStateTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    func testVerifiedPurchaseUnlocksBeforeHistoryCatchesUp() async {
        let store = makeStore()
        defer { store.stop() }
        await store.performPurchase { .verified(self.transaction()) }
        XCTAssertEqual(store.purchaseStatus, .succeeded)
        XCTAssertEqual(store.activeProductIDs, [ProProductID.monthly])
        await store.refreshEntitlements() // Deliberately stale, empty history.
        XCTAssertTrue(store.isPro)
        XCTAssertEqual(store.purchaseStatus, .succeeded)
    }

    func testLateRefreshCannotEraseVerifiedPurchase() async {
        let history = ProSuspendedOperation<[ProTransactionSnapshot]>()
        let store = ProEntitlementStore(now: { self.date }, loadEntitlements: {
            await history.run()
        })
        defer { store.stop() }
        let refresh = Task { await store.refreshEntitlements() }
        await history.waitUntilStarted()
        await store.performPurchase { .verified(self.transaction()) }
        history.resume(returning: [])
        await refresh.value
        XCTAssertTrue(store.isPro)
        XCTAssertEqual(store.purchaseStatus, .succeeded)
    }

    func testExpirationIsCheckedWithoutAnotherStoreKitEvent() async {
        var currentDate = date
        let store = ProEntitlementStore(now: { currentDate }, loadEntitlements: { [] })
        defer { store.stop() }
        await store.performPurchase { .verified(self.transaction()) }
        XCTAssertTrue(store.isPro)
        currentDate = date.addingTimeInterval(3_600)
        XCTAssertFalse(store.isPro)
        XCTAssertTrue(store.activeProductIDs.isEmpty)
        await store.refreshEntitlements()
        XCTAssertEqual(store.purchaseStatus, .idle)
    }

    func testReconciledHistoryCanRemoveAnExpiredSubscription() async {
        var history: [ProTransactionSnapshot] = []
        let store = ProEntitlementStore(now: { self.date }, loadEntitlements: { history })
        defer { store.stop() }
        let purchase = transaction()
        await store.performPurchase { .verified(purchase) }
        history = [purchase]
        await store.refreshEntitlements() // History now acknowledges the purchase.
        history = []
        await store.refreshEntitlements()
        XCTAssertFalse(store.isPro)
    }

    func testSameTransactionWithUpdatedExpiryIsAuthoritative() async {
        var purchase = transaction()
        let store = ProEntitlementStore(now: { self.date }, loadEntitlements: { [purchase] })
        defer { store.stop() }
        store.applyVerifiedTransaction(purchase)
        purchase.expirationDate = date
        await store.refreshEntitlements()
        XCTAssertFalse(store.isPro)
    }

    func testVerifiedRevocationCannotBeUndoneByStaleHistoryOrUpdate() async {
        let purchase = transaction()
        let store = ProEntitlementStore(now: { self.date }, loadEntitlements: { [purchase] })
        defer { store.stop() }
        store.applyVerifiedTransaction(purchase)
        var revoked = purchase
        revoked.revocationDate = date
        store.applyVerifiedTransaction(revoked)
        XCTAssertFalse(store.isPro)
        await store.refreshEntitlements()
        store.applyVerifiedTransaction(purchase)
        XCTAssertFalse(store.isPro)
    }

    func testOlderRevocationCannotRemoveRenewedSubscription() {
        let store = makeStore()
        defer { store.stop() }
        var renewal = transaction()
        renewal.transactionID = 2
        renewal.purchaseDate = date.addingTimeInterval(1)
        store.applyVerifiedTransaction(renewal)
        var oldPurchase = transaction()
        oldPurchase.revocationDate = date
        store.applyVerifiedTransaction(oldPurchase)
        XCTAssertTrue(store.isPro)
    }

    func testUnverifiedAndInvalidTransactionsCannotUnlock() async {
        let store = makeStore()
        defer { store.stop() }
        await store.performPurchase { .unverified }
        XCTAssertEqual(store.purchaseStatus, .failed(ProStoreCopy.unverified))
        XCTAssertFalse(store.isPro)
        var invalid = transaction()
        invalid.productID = "unknown"
        await store.performPurchase { .verified(invalid) }
        XCTAssertEqual(store.purchaseStatus, .failed(ProStoreCopy.notIncluded))
        XCTAssertFalse(store.isPro)
        invalid = transaction()
        invalid.expirationDate = date
        await store.performPurchase { .verified(invalid) }
        XCTAssertEqual(store.purchaseStatus, .failed(ProStoreCopy.notIncluded))
        XCTAssertFalse(store.isPro)
        invalid = transaction()
        invalid.revocationDate = date
        await store.performPurchase { .verified(invalid) }
        XCTAssertEqual(store.purchaseStatus, .failed(ProStoreCopy.notIncluded))
        XCTAssertFalse(store.isPro)
    }

    func testPendingApprovalCompletesThroughVerifiedUpdate() async {
        let store = makeStore()
        defer { store.stop() }
        await store.performPurchase { .pending }
        XCTAssertEqual(store.purchaseStatus, .pending)
        XCTAssertFalse(store.isPro)
        store.resetTransientStatus()
        XCTAssertEqual(store.purchaseStatus, .pending)
        store.applyVerifiedTransaction(transaction())
        XCTAssertEqual(store.purchaseStatus, .succeeded)
        XCTAssertTrue(store.isPro)
    }

    func testApprovalArrivingBeforePendingResultStillSucceeds() async {
        let store = makeStore()
        defer { store.stop() }
        await store.performPurchase {
            store.applyVerifiedTransaction(self.transaction())
            return .pending
        }
        XCTAssertEqual(store.purchaseStatus, .succeeded)
        XCTAssertTrue(store.isPro)
    }

    func testStalePurchaseResultCannotUndoARevocation() async {
        let store = makeStore()
        defer { store.stop() }
        let purchase = transaction()
        var revoked = purchase
        revoked.revocationDate = date
        store.applyVerifiedTransaction(revoked)
        await store.performPurchase { .verified(purchase) }
        XCTAssertEqual(store.purchaseStatus, .failed(ProStoreCopy.notIncluded))
        XCTAssertFalse(store.isPro)
    }

    func testCancellationFailureAndRestoreMessagesResetForNextPresentation() async {
        let store = makeStore()
        defer { store.stop() }
        await store.performPurchase { .cancelled }
        XCTAssertEqual(store.purchaseStatus, .cancelled)
        store.resetTransientStatus()
        XCTAssertEqual(store.purchaseStatus, .idle)
        await store.performPurchase { throw TestFailure.offline }
        XCTAssertEqual(store.purchaseStatus, .failed(ProStoreCopy.purchaseFailed))
        XCTAssertFalse(store.isPro)
        store.resetTransientStatus()
        XCTAssertEqual(store.purchaseStatus, .idle)
        await store.restore()
        XCTAssertEqual(store.restoreStatus, .nothingToRestore)
        store.resetTransientStatus()
        XCTAssertEqual(store.restoreStatus, .idle)
    }

    func testRestoreFailureDoesNotGrantAccess() async {
        let store = ProEntitlementStore(
            now: { self.date }, loadEntitlements: { [] },
            restorePurchases: { throw TestFailure.offline }
        )
        defer { store.stop() }
        await store.restore()
        XCTAssertEqual(store.restoreStatus, .failed(ProStoreCopy.restoreFailed))
        XCTAssertFalse(store.isPro)
    }

    func testOverlappingPurchaseAndRestoreDoNotStart() async {
        let result = ProSuspendedOperation<ProPurchaseOutcome>()
        var restores = 0
        var extraPurchases = 0
        let store = ProEntitlementStore(
            now: { self.date }, loadEntitlements: { [] },
            restorePurchases: { restores += 1 }
        )
        defer { store.stop() }
        let purchase = Task {
            await store.performPurchase { await result.run() }
        }
        await result.waitUntilStarted()
        XCTAssertEqual(store.purchaseStatus, .inProgress)
        store.resetTransientStatus()
        await store.restore()
        await store.performPurchase {
            extraPurchases += 1
            return .cancelled
        }
        XCTAssertEqual(store.purchaseStatus, .inProgress)
        XCTAssertEqual(restores, 0)
        XCTAssertEqual(extraPurchases, 0)
        result.resume(returning: .cancelled)
        await purchase.value
        XCTAssertEqual(store.purchaseStatus, .cancelled)
    }

    private func makeStore() -> ProEntitlementStore {
        ProEntitlementStore(now: { self.date }, loadEntitlements: { [] }, restorePurchases: {})
    }

    private func transaction() -> ProTransactionSnapshot {
        ProTransactionSnapshot(
            productID: ProProductID.monthly,
            revocationDate: nil,
            expirationDate: date.addingTimeInterval(3_600),
            transactionID: 1,
            purchaseDate: date
        )
    }

    private enum TestFailure: Error { case offline }
}

/// A handshake makes interleaving tests deterministic without sleeps or yields.
@MainActor
private final class ProSuspendedOperation<Value> {
    private var hasStarted = false
    private var started: CheckedContinuation<Void, Never>?
    private var result: CheckedContinuation<Value, Never>?

    func run() async -> Value {
        await withCheckedContinuation { continuation in
            result = continuation
            hasStarted = true
            started?.resume()
            started = nil
        }
    }

    func waitUntilStarted() async {
        guard !hasStarted else { return }
        await withCheckedContinuation { started = $0 }
    }

    func resume(returning value: Value) {
        result?.resume(returning: value)
        result = nil
    }
}

private func pourStoreKitURL(for testClass: AnyClass) -> URL? {
    for bundle in [Bundle(for: testClass), Bundle.main] {
        if let url = bundle.url(forResource: ProProductID.configurationName, withExtension: "storekit") {
            return url
        }
    }
    return nil
}
