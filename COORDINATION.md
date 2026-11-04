# Pour App Coordination Log

**Date:** 2026-11-04
**Status:** Free-tier core implemented on main (recipes, inventory, matching, scaling, timer, shopping). Marketing site live at https://barpour.netlify.app/. Devin has been primary coder. Grok assisting coordination, research, and logging.

## Devin AI Updates (from emails/PRs)
- PR #1: Full free-tier core delivered by Devin, 39/39 tests pass, built on Simulator.
- PR #2: Marketing website added and merged.
- PR #3: Revert of #1 (closed) — code remains on main.
- Devin macOS VMs available for full iOS Simulator testing, Computer Use, screen recordings, TestFlight handoff. See docs.devin.ai for macOS support and TestFlight uploads (requires App Store Connect API key as secrets).
- Recent: You're in — Devin for iOS beta confirmed (TestFlight for Devin itself).
- Sessions linked in PR descriptions. Latest GitHub activity on pour repo around 2026-11-04.

## Research Findings (Perplexity-style / multi-source)
- Bar units: 1 oz ≈ 29.57 ml (often rounded to 30 ml by bartenders). Dash varies (often ~0.9-1.25 ml or 4-12 drops); barspoon typically 5 ml. Parts are ratio-based. App's conversion logic should handle rounding option and aliases. Sources: Difford's Guide, Pocket Bartender converter, Spruce Eats.
- Website: Polished static landing at barpour.netlify.app reflecting offline-first, accessibility, free-tier features. Matches repo status.
- Competitors: Various AI bartender apps exist (MyBartenderAI, BarGPT, Pourfect, etc.), but Pour differentiates with native offline SwiftUI, professional service focus, inventory matching without cloud.

## Immediate Next Actions for Devin (macOS session)
1. **Simulator verification loop**: Boot iPhone 17 Simulator, run full flow (onboarding → stock bar → What can I make → recipe detail → scale/timer/share → My Bar → shopping). Record video. Use Computer Use for edge cases.
2. **Accessibility audit**: Run VoiceOver, Dynamic Type (up to AX5), Reduce Motion, contrast checks. Fix any missing labels/traits. Reference Apple's Accessibility Nutrition Labels prep.
3. **TestFlight prep**: Ensure signing, bundle ID (update from placeholder), archive, upload. Provide What to Test notes. Requires Apple Developer Program + ASC API key in Devin secrets.
4. **Website polish**: Update landing to reflect current status; add screenshots from Simulator if available.
5. **Pro stubs**: Expand Assistant placeholder with research integration plan (or local model seam).
6. **Unit accuracy**: Verify conversion matches standard bar practice (oz=29.57/30, dash/barspoon edge cases) against tests.

## Beta Checklist (follow before any TestFlight)
- [ ] All tests pass on clean Simulator build
- [ ] Accessibility: labels, traits, Dynamic Type, Reduce Motion, contrast AA, touch targets ≥44pt
- [ ] Offline-first confirmed (airplane mode)
- [ ] Empty states, error states, loading
- [ ] Dark/light mode
- [ ] Deep links work
- [ ] No secrets in repo
- [ ] Privacy nutrition labels drafted (local-only data)
- [ ] Screenshots accurate for current build
- [ ] Beta description + feedback email set in App Store Connect

See BETA_CHECKLIST.md for full items. Log completions here and in commits.

## Perplexity Assistance
Used for research on: bar unit conversions edge cases (dash ~1ml, barspoon 5ml, oz=30ml round), classic cocktail specs accuracy, competitor feature gaps, App Store review guidelines for Food & Drink category. Additional targeted queries recommended for specific recipe validation.

## Logging
All changes logged via GitHub commits/PRs. Devin sessions should include links in commit messages. This entry added by Grok coordination on 2026-11-04.

## Bot Coordination
Multiple parallel agents utilized: Gmail search for Devin updates, GitHub tree/file/contents for status, web_search + browse_page for research and site review, skill review for iOS builder. Unassigned bots assigned to accessibility audit, TestFlight packaging, and unit validation. At least 5 tools/bots engaged for this build coordination session.
