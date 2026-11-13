# PourSTL Beta / TestFlight Checklist

Follow before an iPhone/TestFlight beta release. Updated 2026-11-12. See
REVIEW.md and docs/PERSONAL_TESTING.md for current review evidence, simulator
artifacts and installation instructions. Mark items only with evidence from the
specific build being distributed; an unchecked item is not established by a
source review or a historical simulator run.

## Build & Quality
- [ ] Unit and UI tests pass on an available iOS 17+ iPhone simulator; record workflow and commit
- [ ] Clean build (no warnings treated as errors)
- [ ] Bundle ID and signing team match the owner’s Apple provisioning (current development ID: com.pourstl.app)
- [ ] Version/Build incremented
- [ ] Icons and launch screen present

## Functionality
- [ ] Onboarding seeds classic recipes; new users start with an empty bar (demo stock is a Debug-only QA flag)
- [ ] Search + filter chips work offline
- [ ] What can I make matches correctly (normalized ingredients)
- [ ] Scaling (1-24) + oz/ml conversion accurate
- [ ] Timer haptics + Reduce Motion
- [ ] Shopping list add/delete/clear
- [ ] Custom recipe save/edit
- [ ] Deep links `pourstl://` (legacy `pour://` remains supported)
- [ ] Settings persist (appearance, units)

## Accessibility (required for App Store)
- [ ] VoiceOver full navigation, meaningful labels on all controls
- [ ] Dynamic Type scales without clipping (test AX5)
- [ ] Contrast ≥ AA (copper on dark, status colors)
- [ ] Touch targets ≥ 44pt
- [ ] Reduce Motion respected
- [ ] Status never color-only
- [ ] Decorative images accessibilityHidden

## TestFlight Specific
- [ ] Archive + upload via Xcode or Devin macOS
- [ ] Beta App Description + What to Test filled
- [ ] Feedback email set
- [ ] Internal group auto-distribute enabled
- [ ] External requires first build review
- [ ] Screenshots match actual UI (no mockups)

## Security / Privacy
- [ ] No API keys or secrets in source
- [ ] Local-only data (SwiftData)
- [ ] Privacy nutrition labels prepared (no tracking)
- [ ] Archive includes PrivacyInfo.xcprivacy and its required-reason API declaration
- [ ] Privacy report and website policy reflect the distributed app
- [ ] Save failures preserve editor input and never show false success
- [ ] Store initialization failures preserve existing data

## Native verification
- Use the GitHub-hosted macOS workflows for repeatable unit/UI tests and screenshots
- Boot the simulator, complete the personal testing checklist, and record the tested commit
- Verify physical camera, lifecycle and accessibility behavior on an iPhone
- If another coding assistant is available, keep its review evidence separate from executed tests
- Push fixes and re-test the changed behavior

Log all completions in COORDINATION.md and GitHub commits.
