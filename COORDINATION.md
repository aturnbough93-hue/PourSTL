# Pour App Coordination Log

**Date:** 2026-11-03
**Status:** Free-tier core implemented on main (recipes, inventory, matching, scaling, timer, shopping). Marketing site live. Devin has been primary coder.

## Devin AI Updates (from emails/PRs)
- PR #1: Full free-tier core delivered by Devin, 39/39 tests pass, built on Simulator.
- PR #2: Marketing website added and merged.
- PR #3: Revert of #1 (closed) — code remains on main.
- Devin macOS VMs available for full iOS Simulator testing, Computer Use, screen recordings, TestFlight handoff.
- Sessions linked in PR descriptions.

## Immediate Next Actions for Devin (macOS session)
1. **Simulator verification loop**: Boot iPhone 17 Simulator, run full flow (onboarding → stock bar → What can I make → recipe detail → scale/timer/share → My Bar → shopping). Record video.
2. **Accessibility audit**: Run VoiceOver, Dynamic Type (up to AX5), Reduce Motion, contrast checks. Fix any missing labels/traits. Reference Apple's Accessibility Nutrition Labels prep.
3. **TestFlight prep**: Ensure signing, bundle ID (update from placeholder), archive, upload. Provide What to Test notes.
4. **Website polish**: Update landing to reflect current status; add screenshots from Simulator.
5. **Pro stubs**: Expand Assistant placeholder with Perplexity-style research integration plan (or local model seam).

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

## Perplexity Assistance
Use for research on: bar unit conversions edge cases, classic cocktail specs accuracy, competitor feature gaps, App Store review guidelines for Food & Drink category.

## Logging
All changes logged via GitHub commits/PRs. Devin sessions should include links in commit messages.

## Bot Coordination
Multiple parallel agents (research, code review, checklist validation, website, testing) utilized. Unassigned bots assigned to accessibility audit and TestFlight packaging.
