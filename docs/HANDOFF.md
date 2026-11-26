# PourSTL handoff

Updated November 25, 2026. This file records the active release work so it can be
continued from GitHub. Do not rely on old coordination entries as current state.

## Current source

- Repository rename is confirmed: **https://github.com/aturnbough93-hue/PourSTL**. The owner updated About description to “PourSTL — iOS bartender assistant” and homepage to https://pourstl.com. The local origin now uses the renamed repository. Settings API still returns 403; the owner completed those settings in GitHub.
- `main` includes the website and browser app launch ([#31](https://github.com/aturnbough93-hue/PourSTL/pull/31)), iPhone Pro costing and batch prep ([#32](https://github.com/aturnbough93-hue/PourSTL/pull/32)), and the StoreKit test fixture cleanup fix ([#33](https://github.com/aturnbough93-hue/PourSTL/pull/33)). The earlier integration is recorded in [branch reconciliation](BRANCH_RECONCILIATION.md).
- Xcode: `PourSTL.xcodeproj`, schemes **PourSTL** and **PourSTLQA**, source/test folders `PourSTL/`, `PourSTLTests/`, `PourSTLUITests/`.
- App display name/module: **PourSTL**. Development bundle ID: `bar.pourstl.app`. StoreKit placeholders: `bar.pourstl.app.pro.monthly` / `.yearly`, configured in `PourSTL.storekit`. They are not registered App Store products.
- The app’s Privacy Policy link is https://pourstl.com/privacy. Terms of Use stay on Apple’s standard EULA. These pages are served by Pages project `pourstl`.
- Deep links: `pourstl://`; legacy `pour://` remains supported. Existing internal preferences and browser storage keys remain stable. Approved app icon artwork is unchanged.

Product positioning: PourSTL is a bartending app, with connected features planned. Current local feature behavior is documented accurately; “offline” is a capability of today’s testing build, not the overall product identity.

## Hosting

- The canonical site **https://pourstl.com** is served by the GitHub-connected Cloudflare Pages project **pourstl**, including the browser app at `/try` and the `/privacy` and `/support` pages. Cloudflare builds branch previews and deploys `main` to production. See the website README for the build settings and verification steps.
- **https://pourstl.com** is registered with **IONOS SE** and is already the canonical public URL. This repo does not change DNS or add redirects. The assigned Pages hostname stays `pourstl.pages.dev` and is not the canonical URL.
- Wrangler currently has account/user read and Pages write permissions. An earlier zone-create attempt failed with missing `com.cloudflare.api.account.zone.create`. This change does not edit DNS or nameservers.
- Public NS for `pourstl.com` resolve to `amanda.ns.cloudflare.com` and `matt.ns.cloudflare.com`. The earlier IONOS nameservers were `ns1085.ui-dns.biz`, `ns1093.ui-dns.org`, `ns1095.ui-dns.com`, and `ns1122.ui-dns.de`.
- The earlier temporary site at `barpour-7hb.pages.dev` remains available. The preferred legacy `barpour.pages.dev` was registered outside this account and is not managed here.

Exact IONOS/Cloudflare DNS steps: [DOMAIN_SETUP.md](DOMAIN_SETUP.md).
Deployment/build details: [website README](../website/README.md). No API token, certificate or private key is committed.

## Validation and testing

Free iPhone recipes scale up to 24 servings. A verified Pro entitlement unlocks
on-device ingredient costing, batches up to 200 servings, and CSV prep sheets.
Debug UI fixtures cover both tiers without purchasing. Release uses real StoreKit.

The [iOS tests](https://github.com/aturnbough93-hue/PourSTL/actions/runs/45695599134)
and [6.9-inch simulator QA](https://github.com/aturnbough93-hue/PourSTL/actions/runs/45695598973)
passed on PR #33's test merge commit
[`219ce72`](https://github.com/aturnbough93-hue/PourSTL/commit/219ce72de7c84629cb691e6405f7bead169f1dc6).
The fix is test-only: the local fixture allows up to 10 minutes for its first
entitlement sync, bounds later waits, and clears transactions again if StoreKit reports a
subscription after cleanup. A timeout fails the test; it is not treated as an
empty entitlement result. These checks do not replace purchase, restore, and
expiration testing with the configured products in Apple's sandbox.

PourSTL Web opens from the homepage and works without an account. It uses the
native seed catalog and saves custom recipes, favorites, inventory, shopping,
and preferences in the browser. The service worker provides offline access
after it caches the app. See the website README for build and verification steps.

See [personal testing](PERSONAL_TESTING.md) for the downloadable simulator build
and manual checklist. The owner currently has neither a Mac nor an Apple
Developer account. PourSTL Web runs in a browser. Native simulator apps
need a Mac with Xcode. Physical iPhone installation needs Xcode provisioning or
an Apple Developer/TestFlight release. No iPhone installer or TestFlight link
has been delivered.

## Finish and record

1. Repository rename and metadata are complete. Canonical GitHub links use /PourSTL; old /pour links redirect. Preserve the owner’s About description without adding “offline”.
2. Canonical metadata uses https://pourstl.com. Cloudflare deploys the `main` branch to Pages project `pourstl`. The assigned Pages hostname is pourstl.pages.dev.
3. Inspect the latest renamed app unit/Release/UI workflows. Fix genuine failures; record tested commit, SDK/runtime, counts and current screenshots.
4. Confirm the simulator package for the tested commit is downloadable with its manifest, checksum, and guide.
5. Verify the Pages deployment from `main`: homepage CTA, browser app, assets, security headers, and a real 404. Record the results and remaining owner steps.
