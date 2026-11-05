# Pour App Coordination Log

**Date:** 2026-11-05
**Status:** Free-tier core live on main. Marketing site at https://barpour.netlify.app. Devin primary for coding/testing on macOS VM. Grok coordinating, logging, research, quality checks. Beta checklist active — native items pending Simulator verification on Devin Mac.

## Devin AI Updates (from emails/PRs)
- PR #1 merged: full free-tier SwiftUI + SwiftData core, 39/39 tests (historical).
- PR #2 merged: marketing website.
- PR #3 (revert) closed unmerged — core remains on main.
- Devin macOS VMs confirmed available for iOS Simulator, Computer Use, screen recordings, TestFlight. iOS beta for Devin itself confirmed via email.
- Recent GitHub bot activity and sessions around Nov 3-4. SWE-2 Flash model available free through 11/30 in Desktop/CLI.
- Ready for next macOS session: full verification loop + accessibility + TestFlight prep.

## Research Findings (multi-source + Perplexity style)
- Bar units confirmed: 1 oz ≈ 29.57 ml (round to 30 practical). Dash ~0.9-1.25 ml, barspoon ~5 ml. Conversion logic in BarUnits.swift should stay precise; tests cover edges.
- Site reviewed live: matches offline-first free-tier claims, honest "in development" status, GitHub CTA. CSP and security headers noted in REVIEW.md.
- REVIEW.md (Nov 5): strong offline core, data integrity fixes already applied, no secrets, privacy manifest present. P0 remaining: Simulator/device validation, AppIcon, final bundle/signing. Security clean for local-only app.

## Immediate Next Actions for Devin (macOS session)
1. Boot iPhone Simulator (iOS 17+), run full user flow from onboarding through My Bar / shopping / timer / scale. Record session. Computer Use for VoiceOver / Dynamic Type / edge cases.
2. Accessibility audit against BETA_CHECKLIST.md and Apple guidelines. Fix any gaps, commit.
3. Confirm tests pass (`xcodebuild test`). Increment version/build if needed. Prep archive notes for TestFlight.
4. Capture accurate screenshots from Simulator for website update if desired.
5. Unit accuracy spot-check against standard bar practice.

## Beta Checklist Status (2026-11-05)
Native items unchecked pending Devin Mac verification (Linux cannot run iOS SDK). Website checks passed locally per REVIEW.md. Follow BETA_CHECKLIST.md fully before any TestFlight upload. Log completions in commits and here.

## Logging & Bot Coordination
All changes logged in GitHub. This update by Grok coordination 2026-11-05.

Bots / tools utilized this session (≥5):
- Gmail search for Devin updates
- GitHub file/tree/PR/issue reads
- Web search + browse_page for site + Devin macOS docs
- Linear tool discovery
- Skill review (ios-app-builder + skill-creator)

Unassigned bots assigned to: Simulator verification support, checklist tracking, skill improvement for Pour beta process, quality/security re-check.

See BETA_CHECKLIST.md and REVIEW.md for full details. Devin next for coding/testing.

## Codex testing and visual pass — 2026-11-05

- Added copper coupe/drop AppIcon asset catalog and matching website favicons.
- Added a working six-classic browser demo at `try.html` (`/try` on Pages): local bar state, matching/search, serving/unit controls, shopping/restocking, reset confirmation, and copy fallback.
- Classics now support independent custom variations; storage-open failures show non-destructive Retry; Coming soon tools are consolidated.
- Exact native revision `fba2e4a` passed 46 XCTest tests with zero failures: https://github.com/aturnbough93-hue/pour/actions/runs/42034714391 .
- Website checks: 5 static + 7 migration + 10 demo-logic tests passed; 27 browser assertions passed both without and with the production security policy. Desktop/native-concept viewport and 820/390/320px layouts inspected.
- Cloudflare API is reachable, but no authorized Cloudflare account/project connection is present in this session. Requested `barpour.pages.dev` does not resolve here yet. New live deployment remains pending that connection; the old Netlify homepage is reachable but outdated.
- Signing, archive validation, TestFlight/App Store distribution, and real-device accessibility/haptics remain outstanding.
