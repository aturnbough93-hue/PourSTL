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

- Authorized Cloudflare account owns Pages project **pourstl**, live at **https://pourstl.pages.dev**. Commit `6c709ab` is deployed and passed 108 live browser checks. The final copy/build compatibility corrections still need deployment. Deployment method: authenticated Wrangler direct upload; GitHub pushes run quality checks but do not automatically deploy this project.
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


The renamed app at `6c709ab` passed **162/162 unit tests** on both Quality
runners ([push](https://github.com/aturnbough93-hue/PourSTL/actions/runs/43324406322),
[PR](https://github.com/aturnbough93-hue/PourSTL/actions/runs/43324412991)),
with verified universal Release archives and a matched Xcode 16.4 / SDK 18.5 /
simulator iOS 18.5 stack. [Full QA 43324406233](https://github.com/aturnbough93-hue/PourSTL/actions/runs/43324406233)
passed **184/185**: all 162 unit tests and 22 of 23 UI tests, with zero skips.
The remaining failure is the unknown-barcode stock-toggle UI interaction. Its
coordinate tap did not establish the off state before saving. The persistence
unit tests pass; the UI helper is being corrected with strict state assertions.
All eight current 1320×2868 screenshots were checked visually without obvious
clipping. Settings correctly shows the free account's Upgrade state.

Subscription listener readiness, StoreKit fixture cleanup, Debug-only free UI
accounts, and visible recipe navigation now pass. Release always uses real
StoreKit. The isolation regression purchases a real local fixture before proving
it cannot leak into the free UI scenario. **The final UI rerun must pass before
release/merge.** A draft simulator prerelease has verified assets attached but
is not public yet.

Local website checks pass: 10 static, 9 Cloudflare build and 10 demo logic tests.
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
