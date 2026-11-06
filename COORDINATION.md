# Pour App Coordination Log

**Date:** 2026-11-06
**Status:** Free-tier core live on main. Marketing site live (https://barpour.pages.dev). Devin primary for coding/testing on macOS VM. Grok coordinating, logging, research, quality checks, and bot utilization. Beta checklist active — native items pending Simulator verification on Devin Mac.

## Devin AI Updates (from emails/PRs as of 2026-11-06)
- PR #1 merged: full free-tier SwiftUI + SwiftData core.
- PR #2 merged: marketing website.
- PR #3 (revert) closed unmerged — core remains on main.
- Open Dependabot PR #4: bump actions/checkout.
- Devin macOS VMs confirmed available for iOS Simulator, Computer Use, screen recordings, TestFlight. iOS beta for Devin itself confirmed via email (TestFlight).
- SWE-2 Flash model available free through 11/30 in Desktop/CLI.
- Recent Grok automation emails confirm verification loop ready and core live.
- Ready for next macOS session: full verification loop + accessibility + TestFlight prep.

## Research Findings
- Site live and matches offline-first free-tier claims, honest "in development" status, GitHub CTA.
- REVIEW.md (Nov 5): strong offline core, data integrity fixes applied, no secrets, privacy manifest present. P0 remaining: Simulator/device validation, AppIcon confirmation, final bundle/signing.
- Security clean for local-only app. No API keys in source.

## Immediate Next Actions for Devin (macOS session)
1. Boot iPhone Simulator (iOS 17+), run full user flow from onboarding through My Bar / shopping / timer / scale. Record session. Computer Use for VoiceOver / Dynamic Type / edge cases.
2. Accessibility audit against BETA_CHECKLIST.md and Apple guidelines. Fix any gaps, commit and push.
3. Confirm tests pass (`xcodebuild test`). Increment version/build if needed. Prep archive notes for TestFlight.
4. Capture accurate screenshots from Simulator for website update if desired.
5. Unit accuracy spot-check against standard bar practice.
6. Coordinate with Perplexity for any research during testing.

## Beta Checklist Status (2026-11-06)
Native items unchecked pending Devin Mac verification (Linux cannot run iOS SDK). Website checks passed. Follow BETA_CHECKLIST.md fully before any TestFlight upload. Log completions in commits and here.

## Logging & Bot Coordination
All changes logged in GitHub. This update by Grok coordination 2026-11-06.

Bots / tools utilized this session (≥5):
- Gmail search for Devin AI updates
- GitHub get_file_contents, get_repository_tree, search_pull_requests, get_me
- Web search for live site and app status
- Linear list_issues
- Skill review (ios-app-builder + skill-creator)
- Netlify tool discovery
- Notion search capability

Unassigned bots assigned to: Simulator verification support, checklist tracking, skill improvement for Pour beta process, quality/security re-check, website deployment coordination.

See BETA_CHECKLIST.md and REVIEW.md for full details. Devin next for coding/testing on Mac.

## Previous Codex testing and visual pass — 2026-11-05
(See prior section for details on AppIcon, browser demo, CI tests, etc.)
