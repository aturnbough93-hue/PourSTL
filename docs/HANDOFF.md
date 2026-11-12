# PourSTL handoff

Updated November 12, 2026. This file records the active release work so it can be
continued from GitHub. Do not rely on old coordination entries as current state.

## Current source

- Repository currently accessible at `aturnbough93-hue/pour`; requested new name **PourSTL**. Settings API calls return 403 through the available connection, including after owner GitHub CLI sign-in. Rename is not yet confirmed.
- Integration branch: `codex/pour-testing-release`; release PR #16 includes the heads of #12–15 and every audited legacy branch. See [branch reconciliation](BRANCH_RECONCILIATION.md).
- Xcode: `PourSTL.xcodeproj`, schemes **PourSTL** and **PourSTLQA**, source/test folders `PourSTL/`, `PourSTLTests/`, `PourSTLUITests/`.
- App display name/module: **PourSTL**. Development bundle ID: `com.pourstl.app`. StoreKit placeholders: `com.pourstl.app.pro.monthly` / `.yearly`, configured in `PourSTL.storekit`. They are not registered App Store products.
- Deep links: `pourstl://`; legacy `pour://` remains supported. Existing internal preferences and browser storage keys remain stable. Approved app icon artwork is unchanged.

## Hosting

- Authorized Cloudflare account owns Pages project **pourstl**, assigned **https://pourstl.pages.dev**. Deployment method: authenticated Wrangler direct upload; GitHub pushes run quality checks but do not automatically deploy this project.
- Selected primary domain: **https://pourstl.com**, registered with **IONOS SE**. It must be added to Cloudflare's Free plan, DNS configured, and IONOS nameservers changed before its HTTPS site is considered live.
- Wrangler currently has account/user read and Pages write permissions. Creating the zone failed with missing `com.cloudflare.api.account.zone.create`; no nameserver or DNS record changes have been made by the agent.
- Current IONOS nameservers from RDAP: `ns1085.ui-dns.biz`, `ns1093.ui-dns.org`, `ns1095.ui-dns.com`, `ns1122.ui-dns.de`. These are the current registrar settings, **not** the Cloudflare nameservers to enter. Obtain the two assigned Cloudflare nameservers from that domain's dashboard.
- The earlier temporary site at `barpour-7hb.pages.dev` remains available. The preferred legacy `barpour.pages.dev` was registered outside this account and is not managed here.

Deployment/build details: [website README](../website/README.md). No API token, certificate or private key is committed.

## Validation and testing

Before the rename, 158 unit tests passed with zero failures/skips, and the
universal Release simulator archive passed SHA-256, archive, actual executable
architecture, simulator-platform and privacy-manifest checks. Initial full QA
passed 180/181: XCTest could not calculate the visible SwiftUI Menu hit point.
The harness now taps its verified on-screen center and still requires the
menu, sheet and actual assistant response. StoreKit test fixtures clear local
transactions, and the free-tier UI smoke asserts the Upgrade state.

The renamed project must pass new macOS CI. Both scripts now select a runtime
compatible with the active Xcode simulator SDK, prefer a matching major/minor,
and reject newer runtimes from another installed Xcode. The previous run used
Xcode 16.4 with an iOS 26.2 runtime; that mismatch must not recur.

Website copy and its 1200×630 PourSTL social image are updated. Local regression
checks passed (10 static, 7 Cloudflare build, 10 demo logic); final live checks
and native run IDs will be added after deployment/testing.

See [personal testing](PERSONAL_TESTING.md) for the downloadable simulator build
and manual checklist. The owner currently has neither a Mac nor an Apple
Developer account. The browser demo works on iPhone now; native simulator apps
need a Mac with Xcode. Physical iPhone installation needs Xcode provisioning or
an Apple Developer/TestFlight release. No iPhone installer or TestFlight link
has been delivered.

## Finish and record

1. Complete/verify the repository rename and update its description/homepage to PourSTL / https://pourstl.com. Update canonical GitHub links after the actual rename; existing /pour links redirect after a successful rename.
2. Add pourstl.com to Cloudflare, connect its assigned nameservers at IONOS, set the Pages CNAMEs, attach apex/www domains, and verify DNS, HTTPS and redirects before claiming the custom domain is live. Preserve mail records.
3. Inspect the latest renamed app unit/Release/UI workflows. Fix genuine failures; record tested commit, SDK/runtime, counts and current screenshots.
4. Merge PR #16 normally after required checks; confirm #12–15 are marked merged and every audited remote head is an ancestor of main. Keep superseded revert history reconciled without applying its deletions.
5. Publish the tested simulator prerelease/package with manifest, checksum and guide. Confirm the documented download exists before final handoff.
6. Deploy from the final reviewed main commit, verify pages/demo/assets/security headers/unknown 404, then update this handoff and coordination status with actual results and remaining owner steps.
