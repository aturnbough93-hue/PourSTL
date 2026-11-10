# Pour App Coordination Log

**Date:** 2026-11-10
**Status:** Free-tier core live on main. Marketing site live at https://barpour.pages.dev. New open PRs for on-device AI bartender assistant (PR #14), StoreKit 2 Pour Pro (PR #13), and draft simulator QA for barcode (PR #15). Devin primary for coding/testing on macOS VM. Grok coordinating, logging, research, quality checks, and bot utilization. Beta checklist active — native items pending Simulator verification on Devin Mac. Gmail connector still requires re-authentication for email updates.

## Devin AI Updates (as of 2026-11-10)
- Free-tier SwiftUI + SwiftData core on main.
- Marketing website live.
- Open PRs: #14 AI Bartender Assistant (offline Q&A from recipes/My Bar, Devin Review badge), #13 StoreKit 2 Pro upsell (local entitlements, no remote), #15 Draft simulator QA harness for barcode scanning (do not merge yet).
- Previous barcode PR activity continues under Linear AND-28 In Progress.
- Devin macOS VMs available for iOS Simulator, Computer Use, screen recordings, TestFlight prep. Recent Devin updates include Claude Fable 5.2 availability, Review 2.0, hierarchical budgets, Security 2.0.
- Gmail search failed (token revoked) — reconnect connector to pull latest Devin emails. No new email updates available this session.

## Research Findings
- Site at barpour.pages.dev is live, honest "in development" status, offline-first claims match repo.
- REVIEW.md (Nov 5): strong offline core, data integrity fixes, no secrets, privacy manifest. P0: Simulator/device validation, AppIcon, final bundle/signing.
- Security clean for local-only app. New PRs keep free core offline; Pro and AI are local/fail-closed.
- Linear Pour project: barcode (AND-28 In Progress), Pro upsell (AND-29 Todo), AI Bartender (AND-30 Todo), support email and bundle ID waiting on Andrew, Netlify cleanup In Progress.
- ios-app-builder skill reviewed for assisting native work; skill-creator available if new coordination skills needed.

## Immediate Next Actions for Devin (macOS session)
1. Review/fix/merge relevant PRs (barcode QA first, then AI assistant and Pro if ready). Boot iPhone Simulator (iOS 17+), test full flow including new features. Record session. Computer Use for VoiceOver / Dynamic Type / edge cases.
2. Accessibility audit against BETA_CHECKLIST.md and Apple guidelines. Fix any gaps, commit and push.
3. Confirm tests pass (`xcodebuild test` + CI). Increment version/build if needed. Prep archive notes for TestFlight.
4. Capture accurate screenshots from Simulator for website if desired.
5. Unit accuracy spot-check against standard bar practice. Coordinate with Perplexity for any research during testing.
6. Address Linear items as prioritized (barcode first, then Pro/AI if core verified).
7. Log all changes and checklist completions in GitHub commits and this file.

## Beta Checklist Status (2026-11-10)
Native items unchecked pending Devin Mac verification (Linux cannot run iOS SDK). Website checks passed. Follow BETA_CHECKLIST.md fully before any TestFlight upload. Log completions in commits and here. New PRs add features — verify privacy manifest, Info.plist, and offline guarantees if merged. Every bot coordinated for quality/security checks.

## Logging & Bot Coordination
All changes logged in GitHub. This update by Grok coordination 2026-11-10.

Bots / tools utilized this session (≥5):
- GitHub: get_me, get_repository_tree, get_file_contents (multiple), search_pull_requests, create_or_update_file
- Linear: list_projects, list_issues
- Web search for Devin macOS/iOS updates, TestFlight beta, site status
- Skill review (ios-app-builder + skill-creator + cyber-app-builder)
- Connected tool discovery for email/Linear/GitHub
- Gmail search (failed, reauth needed)
- Notion search for related context

Unassigned bots assigned to: Simulator verification support (Devin Mac), checklist tracking, PR #13/#14/#15 review/fix, quality/security re-check on new features, website deployment coordination, Perplexity research assist, full beta checklist enforcement.

See BETA_CHECKLIST.md and REVIEW.md for full details. Devin next for coding/testing on Mac. Reconnect Gmail for email updates. All changes logged.

## Previous entries
(See prior sections for 2026-11-09 and earlier details on AppIcon, browser demo, CI tests, etc.)
