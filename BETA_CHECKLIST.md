# Pour Beta / TestFlight Checklist

Follow before every beta build. Updated 2026-11-03.

## Build & Quality
- [ ] `xcodebuild test` passes 100% on iPhone 17 Simulator
- [ ] Clean build (no warnings treated as errors)
- [ ] Bundle ID set to final (com.yourteam.pour)
- [ ] Version/Build incremented
- [ ] Icons and launch screen present

## Functionality
- [ ] Onboarding seeds demo inventory
- [ ] Search + filter chips work offline
- [ ] What can I make matches correctly (normalized ingredients)
- [ ] Scaling (1-24) + oz/ml conversion accurate
- [ ] Timer haptics + Reduce Motion
- [ ] Shopping list add/delete/clear
- [ ] Custom recipe save/edit
- [ ] Deep links `pour://`
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

## Devin macOS Verification
- Boot Simulator, full user flow, record session
- Computer Use taps for edge cases
- Push fixes and re-test in same session

Log all completions in COORDINATION.md and GitHub commits.
