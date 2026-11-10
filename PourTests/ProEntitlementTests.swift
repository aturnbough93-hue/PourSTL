import StoreKit
import StoreKitTest
import XCTest
@testable import Pour

final class ProEntitlementLogicTests: XCTestCase {

    func testProductIDsStayInOneList() {
        XCTAssertEqual(ProProductID.ordered, [
            "com.devin.pour.pro.monthly",
            "com.devin.pour.pro.yearly",
        ])
        XCTAssertEqual(ProProductID.all, Set(ProProductID.ordered))
        XCTAssertEqual(ProProductID.privacyPolicyURL.absoluteString, "https://barpour.pages.dev/privacy.html")
    }

    func testStoreKitFileMatchesProductIDs() throws {
        let url = try XCTUnwrap(
            pourStoreKitURL(for: ProEntitlementLogicTests.self),
            "Pour.storekit must be copied into the app or test bundle"
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
            productID: "com.devin.pour.pro.lifetime",
            revocationDate: nil,
            expirationDate: nil
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
        XCTAssertFalse(ProGate.proPlaceholders.contains(.barcodeScanner))
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
    private static var sharedSession: SKTestSession?

    override func setUp() async throws {
        if Self.sharedSession == nil {
            let url = try XCTUnwrap(
                pourStoreKitURL(for: ProEntitlementStoreTests.self),
                "Pour.storekit must be copied into the app or test bundle"
            )
            Self.sharedSession = try SKTestSession(contentsOf: url)
        }
        session = Self.sharedSession
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        session.askToBuyEnabled = false
        session.failTransactionsEnabled = false
        store = ProEntitlementStore()
        await store.start()
    }

    override func tearDown() async throws {
        store?.stop()
        store = nil
        session = nil
    }

    func testLaunchWithoutPurchaseIsNotPro() {
        XCTAssertTrue(ProRuntime.isUnitTestHost)
        XCTAssertTrue(store.hasResolvedEntitlements)
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

    func testPurchaseMonthlyGrantsEntitlement() async throws {
        try await purchase(ProProductID.monthly)
        XCTAssertEqual(store.purchaseStatus, .succeeded)
        XCTAssertTrue(store.isPro)
        XCTAssertEqual(store.activeProductIDs, [ProProductID.monthly])
    }

    func testTransactionUpdatesGrantEntitlement() async throws {
        XCTAssertFalse(store.isPro)
        try session.buyProduct(productIdentifier: ProProductID.yearly)
        let unlocked = await waitUntil { self.store.isPro }
        XCTAssertTrue(unlocked)
        XCTAssertTrue(store.activeProductIDs.contains(ProProductID.yearly))
    }

    func testCurrentEntitlementsOnLaunch() async throws {
        try session.buyProduct(productIdentifier: ProProductID.monthly)
        store.stop()
        let relaunched = ProEntitlementStore()
        await relaunched.start()
        let unlocked = await waitUntil {
            if relaunched.isPro { return true }
            await relaunched.refreshEntitlements()
            return relaunched.isPro
        }
        XCTAssertTrue(unlocked)
        XCTAssertTrue(relaunched.hasResolvedEntitlements)
        XCTAssertTrue(relaunched.activeProductIDs.contains(ProProductID.monthly))
        relaunched.stop()
    }

    func testExpiredSubscriptionRemovesEntitlement() async throws {
        try session.buyProduct(productIdentifier: ProProductID.monthly)
        let unlocked = await waitUntil {
            await self.store.refreshEntitlements()
            return self.store.isPro
        }
        XCTAssertTrue(unlocked)
        try session.expireSubscription(productIdentifier: ProProductID.monthly)
        let removed = await waitUntil {
            await self.store.refreshEntitlements()
            return !self.store.isPro
        }
        XCTAssertTrue(removed)
        XCTAssertFalse(store.activeProductIDs.contains(ProProductID.monthly))
    }

    func testRestoreFindsExternalPurchase() async throws {
        try session.buyProduct(productIdentifier: ProProductID.yearly)
        let present = await waitUntil {
            await self.store.refreshEntitlements()
            return self.store.isPro
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

    func testFailedPurchaseDoesNotGrantEntitlement() async throws {
        await store.loadProducts()
        session.failTransactionsEnabled = true
        await store.purchase(productID: ProProductID.monthly)
        XCTAssertEqual(store.purchaseStatus, .failed(ProStoreCopy.purchaseFailed))
        XCTAssertFalse(store.isPro)
    }

    func testMissingProductDoesNotGrantEntitlement() async {
        await store.purchase(productID: ProProductID.monthly)
        XCTAssertEqual(store.purchaseStatus, .failed(ProStoreCopy.productMissing))
        XCTAssertFalse(store.isPro)
    }

    private func purchase(_ productID: String) async throws {
        await store.loadProducts()
        XCTAssertEqual(store.productsState, .loaded)
        await store.purchase(productID: productID)
    }

    private func waitUntil(timeout: TimeInterval = 10, _ condition: @MainActor () async -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await condition() { return true }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return await condition()
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
