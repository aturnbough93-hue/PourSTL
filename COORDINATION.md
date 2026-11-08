# Pour App Coordination Log

**Date:** 2026-11-08
**Status:** Free-tier core live on main. Marketing site live and matching claims at https://barpour.pages.dev (Cloudflare Pages). Devin primary for coding/testing on macOS VM. Grok coordinating, logging, research, quality checks, and bot utilization. Beta checklist active — native items pending Simulator verification on Devin Mac. Gmail connector requires re-authentication for email updates.

## Devin AI Updates (as of 2026-11-08)
- Free-tier SwiftUI + SwiftData core on main (PR #1).
- Marketing website live (PR #2).
- Open PR #10: offline barcode scanning to My Bar (Cursor agent). Latest CI run failed on follow-up fix commit; prior run succeeded. Devin Review badge present. Linear AND-28 In Progress.
- Dependabot and other PRs resolved or closed as needed.
- Devin macOS VMs available for iOS Simulator, Computer Use, screen recordings, TestFlight prep. SWE-2 Flash free through 11/30 in Desktop/CLI.
- Recent Cognition updates: Devin Security 2.0, Review 2.0, hierarchical budgets, SWE-2 Flash model.
- Gmail search failed (token revoked) — reconnect connector to pull latest Devin emails.

## Research Findings
- Site at barpour.pages.dev is live, honest "in development" status, offline-first claims match repo, GitHub CTA present. Browser demo available.
- REVIEW.md (Nov 5): strong offline core, data integrity fixes, no secrets, privacy manifest. P0: Simulator/device validation, AppIcon, final bundle/signing.
- Security clean for local-only app. No API keys in source. Open barcode PR adds camera permission (local-only, no network lookup).
- Linear Pour project tracks: barcode (AND-28 In Progress), Pro upsell (AND-29 Todo), AI Bartender (AND-30 Todo), support email and bundle ID waiting on Andrew, Netlify cleanup In Progress.

## Immediate Next Actions for Devin (macOS session)
1. Review/fix/merge PR #10 barcode scanning. Boot iPhone Simulator (iOS 17+), test full flow including new barcode (camera + no-camera fallback). Record session. Computer Use for VoiceOver / Dynamic Type / edge cases.
2. Accessibility audit against BETA_CHECKLIST.md and Apple guidelines. Fix any gaps, commit and push.
3. Confirm tests pass (`xcodebuild test` + CI). Increment version/build if needed. Prep archive notes for TestFlight.
4. Capture accurate screenshots from Simulator for website if desired.
5. Unit accuracy spot-check against standard bar practice. Coordinate with Perplexity for any research during testing.
6. Address Linear items as prioritized (barcode first, then Pro/AI if core verified).

## Beta Checklist Status (2026-11-08)
Native items unchecked pending Devin Mac verification (Linux cannot run iOS SDK). Website checks passed. Follow BETA_CHECKLIST.md fully before any TestFlight upload. Log completions in commits and here. Open barcode PR adds new permission — verify privacy manifest and Info.plist if merged.

## Logging & Bot Coordination
All changes logged in GitHub. This update by Grok coordination 2026-11-08.

Bots / tools utilized this session (≥5):
- GitHub: get_me, get_repository_tree, get_file_contents (multiple), search_pull_requests, search_commits, actions_list, create_or_update_file
- Linear: list_issues
- Web search + browse_page for site and Devin updates
- Skill review (ios-app-builder + skill-creator)
- Connected tool discovery for email/Linear/GitHub

Unassigned bots assigned to: Simulator verification support (Devin Mac), checklist tracking, PR #10 review/fix, quality/security re-check on barcode changes, website deployment coordination, Perplexity research assist.

See BETA_CHECKLIST.md and REVIEW.md for full details. Devin next for coding/testing on Mac. Reconnect Gmail for email updates.

## Previous entries
(See prior sections for 2026-11-06 and earlier details on AppIcon, browser demo, CI tests, etc.)
