# PourSTL handoff

Updated November 12, 2026. This file records the active release work so it can be
continued from GitHub. Do not rely on old coordination entries as current state.

## Current source

- Repository rename is confirmed: **https://github.com/aturnbough93-hue/PourSTL**. The owner updated About description to “PourSTL — iOS bartender assistant” and homepage to https://pourstl.com. The local origin now uses the renamed repository. Settings API still returns 403; the owner completed those settings in GitHub.
- Integration branch: `codex/pour-testing-release`; release PR #16 includes the heads of #12–15 and every audited legacy branch. See [branch reconciliation](BRANCH_RECONCILIATION.md).
- Xcode: `PourSTL.xcodeproj`, schemes **PourSTL** and **PourSTLQA**, source/test folders `PourSTL/`, `PourSTLTests/`, `PourSTLUITests/`.
- App display name/module: **PourSTL**. Development bundle ID: `com.pourstl.app`. StoreKit placeholders: `com.pourstl.app.pro.monthly` / `.yearly`, configured in `PourSTL.storekit`. They are not registered App Store products.
- The app’s Privacy Policy link uses the verified live https://pourstl.pages.dev/privacy while custom-domain DNS is pending. This is the same owned policy served by the Pages project.
- Deep links: `pourstl://`; legacy `pour://` remains supported. Existing internal preferences and browser storage keys remain stable. Approved app icon artwork is unchanged.

Product positioning: PourSTL is a bartending app, with connected features planned. Current local feature behavior is documented accurately; “offline” is a capability of today’s testing build, not the overall product identity.

## Hosting

- Authorized Cloudflare account owns Pages project **pourstl**, live at **https://pourstl.pages.dev**. The PourSTL rebrand was deployed from commit `94f52f8` and passed 108 live browser checks. Deployment method: authenticated Wrangler direct upload; GitHub pushes run quality checks but do not automatically deploy this project.
- Future custom domain: **https://pourstl.com**, registered with **IONOS SE**. The owner is handling it separately and explicitly deferred switching the live site. **https://pourstl.pages.dev remains the current primary address**. It must be added to Cloudflare's Free plan, DNS configured, and IONOS nameservers changed before its HTTPS site is considered live.
- Wrangler currently has account/user read and Pages write permissions. Creating the zone failed with missing `com.cloudflare.api.account.zone.create`; no nameserver or DNS record changes have been made by the agent.
- Current IONOS nameservers from RDAP: `ns1085.ui-dns.biz`, `ns1093.ui-dns.org`, `ns1095.ui-dns.com`, `ns1122.ui-dns.de`. These are the current registrar settings, **not** the Cloudflare nameservers to enter. Obtain the two assigned Cloudflare nameservers from that domain's dashboard.
- The earlier temporary site at `barpour-7hb.pages.dev` remains available. The preferred legacy `barpour.pages.dev` was registered outside this account and is not managed here.

Exact IONOS/Cloudflare DNS steps: [DOMAIN_SETUP.md](DOMAIN_SETUP.md).
Deployment/build details: [website README](../website/README.md). No API token, certificate or private key is committed.

## Validation and testing

Operational note: on the matched Xcode 16.4 / iOS 18.5 stack, local StoreKit
integration tests consumed about 13 minutes on one successful runner (the
entitlement-on-launch case about 9.5 minutes). A long-running simulator job is
not by itself evidence of a failure. Quality CI allows 45 minutes; QA allows 50.
Inspect the actual test summary and logs before retrying or claiming success.


The renamed app at `c6854e7` passed **161/161 unit tests** on both Quality
runners, with verified universal Release archives and a matched Xcode 16.4 /
SDK 18.5 / simulator iOS 18.5 stack. However, full QA run 43318655276 failed
**5 of 184 checks**: one delayed StoreKit update, three tests trying to tap an
offscreen horizontal recipe chip, and a free-tier UI check inheriting a local
StoreKit purchase fixture. The earlier assistant Menu issue was fixed and its
UI test passed in this run.

Current fixes wait for subscription listener startup, verify StoreKit fixture
cleanup, isolate Debug UI navigation tests from real transaction history, and
open a visible filtered recipe card. Release always uses real StoreKit. The
new regression proves an actual purchased fixture cannot leak into the free UI
scenario. Strict transaction verification and visible navigation assertions are
retained. **New native CI must pass before release/merge.**

Local website checks pass: 10 static, 8 Cloudflare build and 10 demo logic tests.
The PourSTL site and 1200×630 social image passed 108 live browser checks on the
working Pages address, including desktop/mobile layouts, demo interactions,
assets, security headers, unknown 404, and metadata.

See [personal testing](PERSONAL_TESTING.md) for the downloadable simulator build
and manual checklist. The owner currently has neither a Mac nor an Apple
Developer account. The browser demo works on iPhone now; native simulator apps
need a Mac with Xcode. Physical iPhone installation needs Xcode provisioning or
an Apple Developer/TestFlight release. No iPhone installer or TestFlight link
has been delivered.

## Finish and record

1. Repository rename and metadata are complete. Canonical GitHub links use /PourSTL; old /pour links redirect. Preserve the owner’s About description without adding “offline”.
2. Domain switch is deferred to a later session while the owner works on DNS. Keep pourstl.pages.dev live. Follow DOMAIN_SETUP.md only when the owner says pourstl.com is ready; validate HTTPS before switching canonical/social metadata.
3. Inspect the latest renamed app unit/Release/UI workflows. Fix genuine failures; record tested commit, SDK/runtime, counts and current screenshots.
4. Merge PR #16 normally after required checks; confirm #12–15 are marked merged and every audited remote head is an ancestor of main. Keep superseded revert history reconciled without applying its deletions.
5. Publish the tested simulator prerelease/package with manifest, checksum and guide. Confirm the documented download exists before final handoff.
6. Deploy from the final reviewed main commit, verify pages/demo/assets/security headers/unknown 404, then update this handoff and coordination status with actual results and remaining owner steps.
