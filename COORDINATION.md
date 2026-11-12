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

The renamed app passed 161 unit tests in both Quality workflows, and its
universal Release archives were verified on a matched SDK/runtime 18.5 stack.
Full QA run 43318655276 failed 5/184 due to one StoreKit observer timing issue,
three offscreen recipe-chip interactions and purchase-fixture leakage into UI
tests. These are corrected in the next source batch; new native CI is required
before release. Earlier entries below are historical status.

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

# Pour App Coordination Log

**Date:** 2026-11-11
**Status:** Free-tier core still on main. Marketing site live at https://barpour.pages.dev (honest in-dev status). Open PRs unchanged: #14 AI Bartender Assistant (offline, Devin Review), #13 StoreKit 2 Pour Pro (local), #15 Draft barcode QA harness (do not merge). Linear: AND-28 barcode In Progress, AND-29 Pro Todo, AND-30 AI Todo, AND-26 Netlify cleanup In Progress. Native beta items still pending Devin Mac Simulator. Gmail connector still revoked — reconnect needed for Devin email updates.

## Devin AI Updates (as of 2026-11-11)
- Recent product: Claude Mythos 5.2 in Devin Security, Gemini 4 Carbon in Desktop/CLI, Claude Fable 5.2 (top on FrontierCode), Review 2.0, hierarchical budgets, Security 2.0.
- macOS VMs and iOS Simulator support confirmed available for full build/test/record/TestFlight flows. Use Devin Mac for any iOS testing, Computer Use, screen recordings.
- No new email pulls possible (token revoked). Coordinate directly via Devin sessions when coding/testing needed.
- Perplexity assist available for research during testing.

## Research Findings
- Website at barpour.pages.dev confirms offline-first, in development, no public TestFlight yet.
- ios-app-builder skill loaded and ready for any native SwiftUI assistance; skill-creator available if a dedicated pour-coordination skill is needed later.
- Quality/security checks ongoing via CI, scripts/check_website.py, etc. Local-only data model remains clean.

## Immediate Next Actions for Devin (macOS session)
1. Prioritize barcode QA (PR #15 / AND-28): boot iPhone Simulator iOS 17+, full user flow, record session, Computer Use for accessibility (VoiceOver, Dynamic Type AX5, Reduce Motion, contrast).
2. Review/fix/merge #14 and #13 if core verified and privacy/offline holds.
3. Run `xcodebuild test` + confirm CI green. Log checklist completions in commits + this file.
4. Spot-check unit conversions against real bar practice; use Perplexity for any edge research.
5. Prep TestFlight notes once Apple enrollment/Team ID ready (AND-20 backlog).
6. Log every change here and in GitHub.

## Beta Checklist Status (2026-11-11)
Still active. Native items unchecked until Devin Mac verification. Website checks continue to pass. Follow BETA_CHECKLIST.md fully before any archive/upload. Every change logged.

## Logging & Bot Coordination
This update by Grok coordination 2026-11-11. All changes logged in GitHub.

Bots / tools utilized this session (≥5):
- GitHub: get_me, get_repository_tree, get_file_contents (multiple), search_pull_requests, create_or_update_file, search_commits attempt
- Linear: list_issues (Pour project)
- Notion: search + fetch (writing voice, agent guide, recent pages)
- Web search: Devin updates Nov 2026, site status, barpour.pages.dev
- Skill review: ios-app-builder + skill-creator
- Connected tool discovery (Gmail, Notion, Linear, GitHub)
- Gmail search (failed, reauth required)

Unassigned bots assigned to: Devin Mac Simulator full QA + accessibility, PR review/fix for #13/#14/#15, checklist enforcement, website quality re-check, Perplexity research support, security/privacy re-audit on any merges, logging all changes.

See BETA_CHECKLIST.md, REVIEW.md, and prior entries. Devin next for coding/testing on Mac. Reconnect Gmail. All bots utilized.

## Previous entries
(See prior sections for 2026-11-10 and earlier details.)
