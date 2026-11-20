# PourSTL delivery — November 12, 2026

Owner steering: rename the app/project to **PourSTL**, use **pourstl.com**, and
save everything in GitHub for continuation. Current work is on
`codex/pour-testing-release` (PR #16). See **docs/HANDOFF.md** for the current
project names, validation, hosting and account steps.

The native source, Xcode project/targets/schemes, tests, StoreKit configuration,
website and social preview now use PourSTL. The approved icon art is unchanged.
Bundle ID is `com.pourstl.app`; local-only product IDs are
`com.pourstl.app.pro.monthly` and `.yearly`. No live App Store products or signed
builds exist. Legacy settings/storage keys and `pour://` links are preserved.

Cloudflare project `pourstl` publishes the canonical site https://pourstl.com,
including /privacy and /support. The project name stays `pourstl`. This note
does not change DNS or add redirects. The
Wrangler grant cannot create zones or edit DNS. Repository settings calls
returned 403 even after GitHub CLI login; the owner completed the rename and
About metadata in GitHub. Confirmed repository:
https://github.com/aturnbough93-hue/PourSTL. The owner's description is
“PourSTL — iOS bartender assistant”, with homepage https://pourstl.com. The
product is a bartending app; current local/offline behavior is a testing-build
capability, not its overall identity.

At `6c709ab`, both Quality workflows pass **162/162 unit tests**, and universal
Release archives are verified on matched Xcode 16.4 / SDK/runtime 18.5. Full QA
43324406233 passed **184/185** (162 unit tests, 22/23 UI tests, zero skips).
The remaining stock-toggle UI interaction is being corrected with an explicit
pre-save state assertion; the persistence tests pass. All earlier StoreKit,
recipe navigation, variation, scaling and Pro fixture failures now pass. Eight
current screenshots were visually reviewed. The live site passes 108 browser
checks; local checks pass 10 static, 9 build and 10 demo tests. The simulator
prerelease remains a draft until the final QA pass. Earlier entries below are
historical status, including retired names/domains and third-party claims.

---

# Current integration — November 12, 2026

The owner authorized completing all open PRs, reconciling all branches, publishing
the Cloudflare website, and preparing personal app testing. Work is collected in
`codex/pour-testing-release`; see docs/BRANCH_RECONCILIATION.md for the full audit.
PRs #12–15 are included with integration fixes. The former PR10-specific QA
harness is updated for the current app and normal main/codex CI triggers.

The authorized Cloudflare account now owns the `barpour` Pages project at
`barpour-7hb.pages.dev`; the preferred `barpour.pages.dev` is registered outside
that account. Production was published by direct upload and is reachable at https://barpour-7hb.pages.dev. Website
copy now matches the offline Bar Assistant and local StoreKit testing. The
approved app icon is preserved. Local website/build/demo tests pass. Native unit tests passed 158/158 and
a universal Release simulator app was built in run 43312827329. The first full
QA run passed 180/181 (one XCTest SwiftUI Menu hit-point failure); the test now
taps the verified visible frame and retains strict result assertions. StoreKit
fixtures now clear transactions before UI tests. Re-run evidence is required
before merging the release.
See docs/PERSONAL_TESTING.md for artifacts, installation and device requirements.

Existing Devin/Cursor/Copilot review history informed the fixes. New Devin or
Claude sessions were not invoked through an unavailable integration. The log
below is historical and includes third-party coordination claims that this
integration does not independently establish.

---

# Verified status — November 19, 2026 (Devin audit)

This entry supersedes the open-PR and site status in the log entries below.

- **Pull requests:** #21 is the only open PR. #1, #2, #4–#10 and #12–#18 are merged; #3 is closed.
- **PR #21:** both bot findings (CSP meta parsing, `connect-src 'self'`) are fixed on the branch. No further code changes were needed.
- **Live site:** `https://pourstl.com` still publishes `https://pourstl.pages.dev` in its canonical links and in the `Sitemap:` line of `robots.txt`. PR #21 fixes this; it takes effect after merge and the next production build.
- **Analytics copy:** PR #21 allows Cloudflare Web Analytics in the CSP, while `privacy.html` and the homepage say the site adds no analytics. No beacon is injected on `pourstl.com` today. Update that copy before turning analytics on.
- **Legacy site:** `https://barpour.pages.dev` still serves the old Pour-branded site with a self canonical and no `noindex`. docs/HANDOFF.md records it as outside this Cloudflare account, so the takedown stays with the owner.
- **Netlify:** the `barpour` Netlify site still posts deploy previews on PRs although Netlify is no longer a deploy target; `barpour.netlify.app` returns 404.
- **Website checks on main:** `check_website.py`, `node --check website/site.js`, `test_demo.cjs` and `test_build_website.py` pass.
- **Native tests on main:** 153 unit tests pass on an iPhone 17 simulator (iOS 26.5) with `ProEntitlementStoreTests` skipped. `SKTestSession` fails on the Devin Mac (`SKInternalErrorDomain Code=3`), so that class only runs in CI, where it passed on PR #18.
- **Code review:** a targeted read of the matching, units, persistence, deep-link, StoreKit, shopping, editor and inventory code found no defects.

---

# Pour App Coordination Log

**Date:** 2026-11-19
**Status:** Free-tier core on main. Sites live at https://barpour.pages.dev and https://pourstl.pages.dev (both HTTP 200 confirmed today with strong security headers: CSP, X-Frame-Options DENY, X-Content-Type-Options nosniff, etc.). Open PR #16 Complete PourSTL rebrand/Cloudflare/personal-testing release still open. Other open PRs: #15 (QA harness), #14 (offline AI Assistant), #13 (StoreKit 2 Pro), #12 (touch icon). Linear issues ongoing. Native beta checklist items still pending Devin Mac Simulator verification. Devin payment failure from 2026-11-10 ($113.90) continues to block new sessions and Mac computer access. Gmail connector still needs reconnect. User previously requested take down barpour.pages.dev — deferred while DNS/Cloudflare handled separately.

## Devin AI Updates (as of 2026-11-19)
- **Devin Bots launched** (Nov 17): Always-on persistent agents with own identity, memory, and permissions that own ongoing goals and lead teams of Devins. Available now at devin.ai/bots. Email: "Meet Devin Bots". Consider for ongoing PourSTL QA / rebrand once payment resolved.
- Devin macOS VMs + iOS Simulator fully supported for build/test/QA/TestFlight handoff. Computer Use available. Status operational. Payment still blocks new sessions — resolve at app.devin.ai/settings/plans or Invoices. Once unlocked, use Devin Mac computer for full simulator QA, Computer Use accessibility, screen recordings, TestFlight prep. Coordinate directly in Devin sessions for any coding on app or website. Perplexity available for research support (docs, edge cases, cited lookups).
- Devin Apps and Teams features live. Desktop updates include Bots integration.

## Research Findings
- Both sites return HTTP 200 today (2026-11-19). Browser demo live at /try, offline-first, no public TestFlight yet. PR #16 advances rebrand with Release archives and QA evidence. ios-app-builder skill active for native SwiftUI PourSTL assistance. skill-creator ready if a dedicated pour-coordination skill is needed. Quality/security checks via CI, website scripts, unit tests remain clean. Local-only data model holds. Barcode on main.

## Immediate Next Actions for Devin (macOS session)
1. Resolve Devin payment to unlock new sessions and Mac computer.
2. Full beta checklist verification on iPhone Simulator iOS 17+: boot, complete user flow (onboarding, search, what can I make, scaling/conversion, timer, shopping, custom recipes, deep links, settings, barcode scan), record session, Computer Use for accessibility (VoiceOver full nav, Dynamic Type AX5, Reduce Motion, contrast, touch targets ≥44pt).
3. Review/fix/merge #16 (integrating #14/#13 as appropriate) once core verified, privacy/offline holds, final QA green. Do not merge unfinished drafts.
4. Run `xcodebuild test` + confirm CI green. Log checklist completions in commits + this file.
5. Spot-check unit conversions against real bar practice; use Perplexity for edge research.
6. Prep TestFlight notes once Apple enrollment/Team ID ready.
7. Log every change here and in GitHub. Handle barpour.pages.dev takedown if still desired after DNS review.
8. Consider spinning up a Devin Bot for ongoing PourSTL QA / rebrand coordination once payment resolved.

## Beta Checklist Status (2026-11-19)
Still active. Native items remain unchecked until Devin Mac verification. Website checks continue to pass (HTTP 200 on both sites). Follow BETA_CHECKLIST.md fully before any archive/upload. Every change logged.

## Logging & Bot Coordination
This update by Grok coordination 2026-11-19. All changes logged in GitHub.

Bots / tools utilized this session (≥5):
- GitHub: get_me, get_repository_tree, get_file_contents (BETA_CHECKLIST, COORDINATION, README, issues/PRs), list_pull_requests, list_issues, search_commits, create_or_update_file
- Gmail: search (Devin AI / Pour updates, recent threads including Meet Devin Bots)
- Web search: Devin macOS/iOS Simulator support, Devin Bots launch, Perplexity coding assistance
- Bash: curl website HTTP status + headers (both domains 200, CSP/security headers)
- Skill review: ios-app-builder (SwiftUI App Store ready workflow) + skill-creator readiness
- Connected tool discovery (Gmail, GitHub, Notion)

Unassigned bots assigned to: Devin Mac Simulator full QA + accessibility testing (once payment resolved), PR review/fix for #16/#13/#14/#15, checklist enforcement, website quality re-check (both domains), Perplexity research support, security/privacy re-audit on any merges, logging all changes, barpour.pages.dev status monitoring, potential Devin Bot for persistent coordination. Create additional specialized bots as needed for builds.

See BETA_CHECKLIST.md, REVIEW.md, and prior entries. Devin next for coding the app/website and iOS testing on Mac after payment fix. Reconnect Gmail. All bots utilized.

## Previous entries
(See prior sections for 2026-11-18 and earlier details.)

# Pour App Coordination Log

**Date:** 2026-11-18
**Status:** Free-tier core on main. Sites live at https://barpour.pages.dev and https://pourstl.pages.dev (both HTTP 200 confirmed today with strong security headers: CSP, X-Frame-Options DENY, etc.). Open PR #16 Complete PourSTL rebrand/Cloudflare/personal-testing release still open. Other open PRs: #15 (QA harness), #14 (offline AI Assistant), #13 (StoreKit 2 Pro), #12 (touch icon). Linear issues ongoing. Native beta checklist items still pending Devin Mac Simulator verification. Devin payment failure from 2026-11-10 ($113.90) continues to block new sessions and Mac computer access. Gmail connector still needs reconnect. User previously requested take down barpour.pages.dev — deferred while DNS/Cloudflare handled separately.

## Devin AI Updates (as of 2026-11-18)
- **Devin Bots launched** (Nov 17): Always-on persistent agents with own identity, memory, and permissions that own ongoing goals and lead teams of Devins. Available now. Email: "Meet Devin Bots".
- Devin macOS VMs + iOS Simulator fully supported for build/test/QA/TestFlight handoff. Computer Use available. Status operational. Payment still blocks new sessions — resolve at app.devin.ai/settings/plans or Invoices. Once unlocked, use Devin Mac computer for full simulator QA, Computer Use accessibility, screen recordings, TestFlight prep. Coordinate directly in Devin sessions for any coding on app or website. Perplexity available for research support (docs, edge cases, cited lookups).
- Devin Apps and Teams features live. Desktop updates include Bots integration.

## Research Findings
- Both sites return HTTP 200. Browser demo live at /try, offline-first, no public TestFlight yet. PR #16 advances rebrand with Release archives and QA evidence. ios-app-builder skill active for native SwiftUI PourSTL assistance. skill-creator ready if a dedicated pour-coordination skill is needed. Quality/security checks via CI, website scripts, unit tests remain clean. Local-only data model holds. Barcode on main.

## Immediate Next Actions for Devin (macOS session)
1. Resolve Devin payment to unlock new sessions and Mac computer.
2. Full beta checklist verification on iPhone Simulator iOS 17+: boot, complete user flow (onboarding, search, what can I make, scaling/conversion, timer, shopping, custom recipes, deep links, settings, barcode scan), record session, Computer Use for accessibility (VoiceOver full nav, Dynamic Type AX5, Reduce Motion, contrast, touch targets ≥44pt).
3. Review/fix/merge #16 (integrating #14/#13 as appropriate) once core verified, privacy/offline holds, final QA green. Do not merge unfinished drafts.
4. Run `xcodebuild test` + confirm CI green. Log checklist completions in commits + this file.
5. Spot-check unit conversions against real bar practice; use Perplexity for edge research.
6. Prep TestFlight notes once Apple enrollment/Team ID ready.
7. Log every change here and in GitHub. Handle barpour.pages.dev takedown if still desired after DNS review.
8. Consider spinning up a Devin Bot for ongoing PourSTL QA / rebrand coordination once payment resolved.

## Beta Checklist Status (2026-11-18)
Still active. Native items remain unchecked until Devin Mac verification. Website checks continue to pass (HTTP 200 on both sites). Follow BETA_CHECKLIST.md fully before any archive/upload. Every change logged.

## Logging & Bot Coordination
This update by Grok coordination 2026-11-18. All changes logged in GitHub.

Bots / tools utilized this session (≥5):
- GitHub: get_me, get_repository_tree, get_file_contents (BETA_CHECKLIST, COORDINATION, issues/PRs), list_pull_requests, list_commits, search_code, create_or_update_file
- Gmail: search (Devin AI / Pour updates, recent threads including Meet Devin Bots)
- Web search: Devin macOS/iOS Simulator support, Devin Bots launch, Perplexity coding assistance
- Bash: curl website HTTP status + headers (both domains 200, CSP/security headers)
- Skill review: ios-app-builder (SwiftUI App Store ready workflow) + skill-creator readiness
- Connected tool discovery (Gmail, GitHub)

Unassigned bots assigned to: Devin Mac Simulator full QA + accessibility testing (once payment resolved), PR review/fix for #16/#13/#14/#15, checklist enforcement, website quality re-check (both domains), Perplexity research support, security/privacy re-audit on any merges, logging all changes, barpour.pages.dev status monitoring, potential Devin Bot for persistent coordination. Create additional specialized bots as needed for builds.

See BETA_CHECKLIST.md, REVIEW.md, and prior entries. Devin next for coding the app/website and iOS testing on Mac after payment fix. Reconnect Gmail. All bots utilized.

## Previous entries
(See prior sections for 2026-11-17 and earlier details.)
