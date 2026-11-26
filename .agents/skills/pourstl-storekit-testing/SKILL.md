---
name: pourstl-storekit-testing
description: Diagnose hangs and validate changes to PourSTL's StoreKit entitlement tests, especially on fresh CI simulators.
---

# PourSTL StoreKit testing

- **Cold-start stall:** On a fresh install with no transaction history, `storekitd` does a one-time transaction sync before answering the first `Transaction.currentEntitlements` query. Without a warm-up, the first `ProEntitlementStore.start()` reaches that query via `refreshEntitlements()` and can appear to hang for minutes.
- **Warm up once:** In [`PourSTLTests/ProEntitlementTests.swift`](../../../PourSTLTests/ProEntitlementTests.swift), `ProEntitlementStoreTests.setUp()` resets the shared `SKTestSession` only once and uses `clearTransactions()` between tests. It calls `finishFirstEntitlementSync()` before starting the store. That helper reads entitlements through `storeKitProductIDs()` once per test process, with a 600-second stall limit. Don't call `AppStore.sync()` in setup.
- **Bound later waits:** Use `raceAgainstDeadline` via `StoreKitEntitlementReader.read`, `bounded`, or `waitUntil` as appropriate. The helper uses unstructured tasks so the caller can stop waiting even if StoreKit ignores cancellation. The normal stall limit is 300 seconds. A `nil` result means a timeout, not an empty entitlement set; fail the test instead of retrying a wedged read.
- **Verify in CI:** Run the full StoreKit group (`ProEntitlementStoreTests`) in the **iOS tests and downloadable simulator app** CI job ([`scripts/test_ios.sh`](../../../scripts/test_ios.sh)), not locally, where restore can stall. A passing re-run alone doesn't establish a fix. Check the first-sync timing, XCTest result bundle, and full-group results on the changed commit.
