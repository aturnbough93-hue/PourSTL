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
