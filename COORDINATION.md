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

Cloudflare project `pourstl` is live at https://pourstl.pages.dev. The purchased
domain `pourstl.com` is at IONOS. The owner is handling its DNS and deferred the
switch; pourstl.pages.dev remains the current primary address. The
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

# Pour App Coordination Log

**Date:** 2026-11-13
**Status:** Free-tier core on main. Marketing site live at https://barpour.pages.dev (HTTP 200). New open PR #16: Complete PourSTL rebrand, Cloudflare website and personal-testing release (integrates prior #12-15, live at pourstl.pages.dev mentioned, universal Release archives, QA nearly green). Open PRs: #16 (rebrand/release), #15 (QA harness), #14 (AI Assistant offline), #13 (StoreKit 2 Pro), #12 (touch icon). Linear: AND-28 barcode In Progress (merged), AND-29 Pro Todo, AND-30 AI Todo, AND-26 Netlify cleanup In Progress. Native beta items still pending Devin Mac Simulator. Devin payment failed on 2026-11-10 ($113.90) — new sessions blocked until resolved. Gmail connector still needs reconnect for email updates.

## Devin AI Updates (as of 2026-11-13)
- Recent product: Devin's new Teams plan (Nov 12) includes Devin Desktop for every user, free sessions powered by SWE-2, SSO, cost controls, standard BAA. Gemini 4 Hydrogen now available in Devin Desktop/CLI (Nov 11, 38.2% on FrontierCode 2.0). Claude Mythos 5.2 in Devin Security (Nov 11), Gemini 4 Carbon (Nov 10), Claude Fable 5.2 top on FrontierCode (Nov 9), Review 2.0, hierarchical budgets, Security 2.0.
- Devin Desktop v3.12.59 / Next builds available. macOS VMs and iOS Simulator support confirmed. Use Devin Mac for any iOS testing, Computer Use, screen recordings, TestFlight prep.
- Payment failure still blocks new sessions. Update payment at app.devin.ai/settings/plans or pay invoice.
- No new email pulls possible (token revoked). Coordinate directly via Devin sessions when coding/testing needed.
- Perplexity assist available for research during testing.

## Research Findings
- Website at barpour.pages.dev confirms offline-first, in development, no public TestFlight yet. PR #16 advances rebrand to PourSTL and personal-testing release with simulator QA evidence.
- ios-app-builder skill loaded and ready for any native SwiftUI assistance; skill-creator available if a dedicated pour-coordination skill is needed later.
- Quality/security checks ongoing via CI, scripts/check_website.py, etc. Local-only data model remains clean. Barcode scanning on main. PR #16 shows strong validation (162 unit tests, QA 184/185).

## Immediate Next Actions for Devin (macOS session)
1. Resolve Devin payment to unlock sessions.
2. Prioritize full beta checklist verification on iPhone Simulator iOS 17+: boot, full user flow (onboarding, search, what can I make, scaling, timer, shopping, custom recipes, deep links, settings, barcode), record session, Computer Use for accessibility (VoiceOver, Dynamic Type AX5, Reduce Motion, contrast).
3. Review/fix/merge #16 (and related #14/#13) if core verified and privacy/offline holds. Do not merge draft QA if not ready.
4. Run `xcodebuild test` + confirm CI green. Log checklist completions in commits + this file.
5. Spot-check unit conversions against real bar practice; use Perplexity for any edge research.
6. Prep TestFlight notes once Apple enrollment/Team ID ready (AND-20 backlog).
7. Log every change here and in GitHub.

## Beta Checklist Status (2026-11-13)
Still active. Native items unchecked until Devin Mac verification. Website checks continue to pass (HTTP 200). Follow BETA_CHECKLIST.md fully before any archive/upload. Every change logged.

## Logging & Bot Coordination
This update by Grok coordination 2026-11-13. All changes logged in GitHub.

Bots / tools utilized this session (≥5):
- GitHub: get_me, get_repository_tree, get_file_contents (multiple), list_pull_requests, pull_request_read (#16), search_commits, create_or_update_file
- Linear: list_issues (Pour project)
- Gmail: search (failed, reauth required)
- Web search: Devin updates Nov 2026, barpour.pages.dev status
- Bash: curl website status check
- Skill review: ios-app-builder + skill-creator
- Connected tool discovery (Gmail, Notion, Linear, GitHub)

Unassigned bots assigned to: Devin Mac Simulator full QA + accessibility (once payment resolved), PR review/fix for #16/#13/#14/#15, checklist enforcement, website quality re-check (including pourstl.pages.dev), Perplexity research support, security/privacy re-audit on any merges, logging all changes.

See BETA_CHECKLIST.md, REVIEW.md, and prior entries. Devin next for coding/testing on Mac after payment fix. Reconnect Gmail. All bots utilized.

## Previous entries
(See prior sections for 2026-11-12 and earlier details.)

# Pour App Coordination Log

**Date:** 2026-11-12
**Status:** Free-tier core on main. Marketing site live at https://barpour.pages.dev. Barcode scanning merged to main (PR #10). Open PRs: #14 AI Bartender Assistant (offline, Devin Review), #13 StoreKit 2 Pour Pro (local), #15 Draft barcode QA harness (do not merge). Linear: AND-28 barcode In Progress (merged), AND-29 Pro Todo, AND-30 AI Todo, AND-26 Netlify cleanup In Progress. Native beta items still pending Devin Mac Simulator. Devin payment failed on 2026-11-10 ($113.90) — new sessions blocked until resolved. Gmail connector still needs reconnect for email updates.

## Devin AI Updates (as of 2026-11-12)
- Recent product: Claude Mythos 5.2 in Devin Security (Nov 11), Gemini 4 Carbon in Desktop/CLI (Nov 10), Claude Fable 5.2 top on FrontierCode (Nov 9), Review 2.0, hierarchical budgets, Security 2.0, SWE-2 Flash free through Nov 30.
- macOS VMs and iOS Simulator support confirmed available. Use Devin Mac for any iOS testing, Computer Use, screen recordings, TestFlight prep.
- Payment failure blocks new sessions. Update payment at app.devin.ai/settings/plans or pay invoice.
- No new email pulls possible (token revoked). Coordinate directly via Devin sessions when coding/testing needed.
- Perplexity assist available for research during testing.

## Research Findings
- Website at barpour.pages.dev confirms offline-first, in development, no public TestFlight yet.
- ios-app-builder skill loaded and ready for any native SwiftUI assistance; skill-creator available if a dedicated pour-coordination skill is needed later.
- Quality/security checks ongoing via CI, scripts/check_website.py, etc. Local-only data model remains clean. Barcode scanning on main.

## Immediate Next Actions for Devin (macOS session)
1. Resolve Devin payment to unlock sessions.
2. Prioritize full beta checklist verification on iPhone Simulator iOS 17+: boot, full user flow (onboarding, search, what can I make, scaling, timer, shopping, custom recipes, deep links, settings, barcode), record session, Computer Use for accessibility (VoiceOver, Dynamic Type AX5, Reduce Motion, contrast).
3. Review/fix/merge #14 and #13 if core verified and privacy/offline holds.
4. Run `xcodebuild test` + confirm CI green. Log checklist completions in commits + this file.
5. Spot-check unit conversions against real bar practice; use Perplexity for any edge research.
6. Prep TestFlight notes once Apple enrollment/Team ID ready (AND-20 backlog).
7. Log every change here and in GitHub.

## Beta Checklist Status (2026-11-12)
Still active. Native items unchecked until Devin Mac verification. Website checks continue to pass. Follow BETA_CHECKLIST.md fully before any archive/upload. Every change logged.

## Logging & Bot Coordination
This update by Grok coordination 2026-11-12. All changes logged in GitHub.

Bots / tools utilized this session (≥5):
- GitHub: get_me, get_repository_tree, get_file_contents (multiple), search_pull_requests, list_commits, create_or_update_file
- Linear: list_issues (Pour project)
- Gmail: search + get_message (Devin payment, Pour updates)
- Web search: Devin updates Nov 2026
- Bash: curl website status check
- Skill review: ios-app-builder + skill-creator
- Connected tool discovery (Gmail, Notion, Linear, GitHub)

Unassigned bots assigned to: Devin Mac Simulator full QA + accessibility (once payment resolved), PR review/fix for #13/#14/#15, checklist enforcement, website quality re-check, Perplexity research support, security/privacy re-audit on any merges, logging all changes.

See BETA_CHECKLIST.md, REVIEW.md, and prior entries. Devin next for coding/testing on Mac after payment fix. Reconnect Gmail. All bots utilized.

## Previous entries
(See prior sections for 2026-11-11 and earlier details.)
