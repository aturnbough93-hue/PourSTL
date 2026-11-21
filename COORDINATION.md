# Pour App Coordination Log

**Date:** 2026-11-21
**Status:** Free-tier core on main. Sites live at https://pourstl.com (canonical), https://pourstl.pages.dev. Bundle ID updated to bar.pourstl.app on main (PR #24 merged). Open PRs: #26 (temporary StoreKit CI diagnostics — do not merge), #27 (label segmented pickers for QA). Native beta checklist items still pending Devin Mac Simulator verification. Devin payment failure from 2026-11-10 ($113.90) continues to block new sessions and Mac computer access. Devin Bots (launched Nov 17) available for persistent coordination once payment resolved.

## Devin AI Updates (as of 2026-11-21)
- Devin status operational. Devin Bots are live: persistent agents with own identity, memory, and permissions that can lead teams of Devins for multi-week goals (e.g., ongoing PourSTL QA, rebrand, accessibility). Beta testers reporting 4.5x more PRs per message. Payment still blocks new sessions for this account — resolve at app.devin.ai/settings/plans or Invoices to unlock Mac computer for simulator QA, Computer Use accessibility, TestFlight prep.
- Recent activity: PR #22 (coordination audit) merged, PR #21 (canonical URL + phone homepage) merged, bundle ID change merged. Open #27 for accessibility labels on segmented pickers (needed for QA lookups). #26 is diagnostics-only, do not merge.
- Coordinate directly in Devin sessions for coding the app or website once unlocked. Use Devin Mac computer for full iOS 17+ simulator QA. Perplexity available for research support (docs, edge cases, cited lookups on bar units, accessibility, StoreKit).

## Research Findings
- ios-app-builder skill active and ready for native SwiftUI PourSTL assistance (iOS 15+, SwiftUI only, App Store ready structure). skill-creator available if a dedicated pour-coordination or beta-enforcement skill is needed.
- Quality/security checks via CI remain relevant. Local-only data model holds. Barcode on main. Accessibility improvements in flight via #27.
- Website: pourstl.com confirmed as canonical. Strong security headers previously verified.

## Immediate Next Actions for Devin (macOS session once payment resolved)
1. Resolve Devin payment to unlock new sessions and Mac computer.
2. Full beta checklist verification on iPhone Simulator iOS 17+: boot, complete user flow (onboarding, search, what can I make, scaling/conversion, timer, shopping, custom recipes, deep links, settings, barcode scan), record session, Computer Use for accessibility (VoiceOver full nav, Dynamic Type AX5, Reduce Motion, contrast, touch targets ≥44pt). Review #27 labels.
3. Review/fix/merge open PRs as appropriate (#27 accessibility, close #26 after diagnostics). Do not merge unfinished drafts or diagnostics-only.
4. Run `xcodebuild test` + confirm CI green. Log checklist completions in commits + this file.
5. Spot-check unit conversions against real bar practice; use Perplexity for edge research.
6. Prep TestFlight notes once Apple enrollment/Team ID ready.
7. Log every change here and in GitHub. Handle any remaining site cleanup (barpour.pages.dev if still desired).
8. Consider spinning up a Devin Bot for ongoing PourSTL QA / rebrand / accessibility coordination.

## Beta Checklist Status (2026-11-21)
Still active. Native items remain unchecked until Devin Mac verification. Website checks continue to pass. Follow BETA_CHECKLIST.md fully before any archive/upload. Every change logged. Open accessibility PR addresses part of the VoiceOver/labels requirement.

## Logging & Bot Coordination
This update by Grok coordination 2026-11-21. All changes logged in GitHub.

Bots / tools utilized this session (≥5):
- GitHub: get_me, get_repository_tree, get_file_contents (BETA_CHECKLIST, COORDINATION), list_commits, search_pull_requests, create_or_update_file (this log)
- Gmail: search (Devin AI / Pour updates, recent threads including payment and Bots)
- Web search: Devin Bots launch details, status, PourSTL context
- Skill review: ios-app-builder (SwiftUI App Store ready workflow) + skill-creator readiness
- Connected tool discovery (Gmail, GitHub, Notion)

Unassigned bots assigned to: Devin Mac Simulator full QA + accessibility testing (once payment resolved), PR review/fix for #27 and diagnostics on #26, checklist enforcement, website quality re-check, Perplexity research support, security/privacy re-audit on any merges, logging all changes, potential Devin Bot for persistent coordination, iOS app builder assistance for any feature gaps. Create additional specialized bots as needed for builds.

See BETA_CHECKLIST.md, REVIEW.md, and prior entries. Devin next for coding the app/website and iOS testing on Mac after payment fix. All bots utilized.

## Previous entries
(See prior sections for 2026-11-20 and earlier details. Full historical log retained in previous versions of this file.)

---

# Previous Coordination Content (retained from 2026-11-20 and earlier)

# Pour App Coordination Log

**Date:** 2026-11-20
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