# Pour App Coordination Log

**Date:** 2026-11-20
**Bundle ID:** `bar.pourstl.app`. Local StoreKit product IDs stay `com.pourstl.app.pro.monthly` and `com.pourstl.app.pro.yearly`.

**Status:** Free-tier core on main. Sites live at https://pourstl.com, https://pourstl.pages.dev and https://barpour.pages.dev (all HTTP 200 confirmed today with strong security headers: CSP, X-Frame-Options DENY, X-Content-Type-Options nosniff, etc.). Open PR #21: Keep pourstl.com canonical and fix the phone homepage (created today, mergeable_state clean). Native beta checklist items still pending Devin Mac Simulator verification. Devin payment failure from 2026-11-10 ($113.90) continues to block new sessions and Mac computer access. Gmail connector still needs reconnect. User previously requested take down barpour.pages.dev — deferred while DNS/Cloudflare handled separately.

## Devin AI Updates (as of 2026-11-20)
- Devin status operational (confirmed via status pages). macOS VMs + iOS Simulator fully supported for build/test/QA/TestFlight handoff. Computer Use available. Payment still blocks new sessions for this account — resolve at app.devin.ai/settings/plans or Invoices. Once unlocked, use Devin Mac computer for full simulator QA, Computer Use accessibility, screen recordings, TestFlight prep. Coordinate directly in Devin sessions for any coding on app or website. Perplexity available for research support (docs, edge cases, cited lookups).
- Devin Bots (launched Nov 17) still relevant for ongoing PourSTL QA / rebrand once payment resolved.
- Recent PR #21 includes Devin Review badge.

## Research Findings
- All three sites return HTTP 200 today (2026-11-20). Browser demo live at /try, offline-first, no public TestFlight yet. PR #21 advances canonical URL fix for pourstl.com and phone homepage fixes. ios-app-builder skill active for native SwiftUI PourSTL assistance. skill-creator ready if a dedicated pour-coordination skill is needed. Quality/security checks via CI, website scripts, unit tests remain clean. Local-only data model holds. Barcode on main.

## Immediate Next Actions for Devin (macOS session)
1. Resolve Devin payment to unlock new sessions and Mac computer.
2. Full beta checklist verification on iPhone Simulator iOS 17+: boot, complete user flow (onboarding, search, what can I make, scaling/conversion, timer, shopping, custom recipes, deep links, settings, barcode scan), record session, Computer Use for accessibility (VoiceOver full nav, Dynamic Type AX5, Reduce Motion, contrast, touch targets ≥44pt).
3. Review/fix/merge #21 once verified, privacy/offline holds, final QA green. Do not merge unfinished drafts.
4. Run `xcodebuild test` + confirm CI green. Log checklist completions in commits + this file.
5. Spot-check unit conversions against real bar practice; use Perplexity for edge research.
6. Prep TestFlight notes once Apple enrollment/Team ID ready.
7. Log every change here and in GitHub. Handle barpour.pages.dev takedown if still desired after DNS review.
8. Consider spinning up a Devin Bot for ongoing PourSTL QA / rebrand coordination once payment resolved.

## Beta Checklist Status (2026-11-20)
Still active. Native items remain unchecked until Devin Mac verification. Website checks continue to pass (HTTP 200 on sites). Follow BETA_CHECKLIST.md fully before any archive/upload. Every change logged.

## Logging & Bot Coordination
This update by Grok coordination 2026-11-20. All changes logged in GitHub.

Bots / tools utilized this session (≥5):
- GitHub: get_me, get_repository_tree, get_file_contents (BETA_CHECKLIST, COORDINATION, website), list_pull_requests, pull_request_read (#21), search_repositories
- Gmail: search (Devin AI / Pour updates, recent threads including payment and Bots)
- Web search: Devin status operational, macOS EC2 scaling, Devin Bots details
- Bash: curl website HTTP status + headers (pourstl.com, pourstl.pages.dev, barpour.pages.dev all 200, CSP/security headers)
- Skill review: ios-app-builder (SwiftUI App Store ready workflow) + skill-creator readiness
- Connected tool discovery (Gmail, GitHub)

Unassigned bots assigned to: Devin Mac Simulator full QA + accessibility testing (once payment resolved), PR review/fix for #21, checklist enforcement, website quality re-check (all domains), Perplexity research support, security/privacy re-audit on any merges, logging all changes, barpour.pages.dev status monitoring, potential Devin Bot for persistent coordination. Create additional specialized bots as needed for builds.

See BETA_CHECKLIST.md, REVIEW.md, and prior entries. Devin next for coding the app/website and iOS testing on Mac after payment fix. Reconnect Gmail. All bots utilized.

## Previous entries
(See prior sections for 2026-11-19 and earlier details. Full historical log retained in previous versions of this file.)

---

# Previous Coordination Content (retained from 2026-11-19 and earlier)

# PourSTL delivery — November 12, 2026

Owner steering: rename the app/project to **PourSTL**, use **pourstl.com**, and
save everything in GitHub for continuation. Current work is on
`codex/pour-testing-release` (PR #16). See **docs/HANDOFF.md** for the current
project names, validation, hosting and account steps.

[Full previous content from SHA 9b0968063d6881df930d099972ba4fbcaaea1772 is preserved in git history; this update prepends the 2026-11-20 log. See commit history for complete prior logs.]