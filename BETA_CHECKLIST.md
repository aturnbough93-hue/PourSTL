# PourSTL Beta / TestFlight Checklist

Follow before an iPhone/TestFlight beta release. Updated 2026-11-12. See
REVIEW.md and docs/PERSONAL_TESTING.md for current review evidence, simulator
artifacts and installation instructions. Mark items only with evidence from the
specific build being distributed; an unchecked item is not established by a
source review or a historical simulator run.

## Automated release checks

- Pull requests run [Quality checks](.github/workflows/ci.yml) and
  [Simulator QA](.github/workflows/qa-simulator-pass.yml): iOS unit/UI tests and a
  Release simulator build, website and Worker regression checks (including
  `/try` startup on desktop and mobile layouts), and static checks for the
  bundle ID, version/build consistency, app icon and launch screen, privacy
  manifest inclusion, Settings support/privacy pages, and common secret
  patterns in tracked files.
- Before publishing, run [Release checks](.github/workflows/release-checks.yml)
  on the exact candidate ref and wait for all jobs to pass. A `v*` tag push
  and a published GitHub Release also rerun the checks; publication itself
  does not wait for Actions. The build number must increase from the highest
  reachable `v*` tag not on the candidate commit or the supplied `base_ref`.
  Without either baseline, only build-number consistency is checked; provide
  `base_ref` to compare a first tagged release with an earlier distributed build.
- A person still verifies distribution signing and provisioning, the
  signed archive and App Store Connect/TestFlight settings (including privacy
  labels), physical-device and Apple sandbox behavior, VoiceOver and other
  accessibility checks, screenshots, and deployed site behavior.

## Build & Quality
- [ ] Unit and UI tests pass on an available iOS 17+ iPhone simulator; record workflow and commit
- [ ] Clean build (no warnings treated as errors)
- [ ] Bundle ID and signing team match the owner’s Apple provisioning (current development ID: bar.pourstl.app)
- [ ] Version/Build incremented
- [ ] Icons and launch screen present

## Functionality
- [ ] Onboarding seeds classic recipes; new users start with an empty bar (demo stock is a Debug-only QA flag)
- [ ] Search + filter chips work offline
- [ ] What can I make matches correctly (normalized ingredients)
- [ ] Free scaling (1–24) + oz/ml conversion accurate
- [ ] Verified Pro access unlocks batches up to 200, ingredient costing and CSV prep sheets; Free opens the upgrade sheet instead
- [ ] With configured products in Apple’s sandbox, verify purchase, restore and expiration; Free tools remain usable
- [ ] Timer haptics + Reduce Motion
- [ ] Shopping list add/delete/clear
- [ ] Custom recipe save/edit
- [ ] Deep links `pourstl://` (legacy `pour://` remains supported)
- [ ] Settings persist (appearance, units)
- [ ] Settings → Support links open the expected pages in the browser: [Get support](https://pourstl.com/support), [Privacy policy](https://pourstl.com/privacy), and [PourSTL website](https://pourstl.com)

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
- [ ] TestFlight beta feedback email set in App Store Connect (separate from the app’s **Get support** link)
- [ ] Internal group auto-distribute enabled
- [ ] External requires first build review
- [ ] Screenshots match actual UI (no mockups)

## Security / Privacy
- [ ] No API keys or secrets in source
- [ ] iPhone recipes and inventory stay in SwiftData; the iPhone Bar Assistant does not call the separate Worker
- [ ] Privacy nutrition labels prepared (no tracking)
- [ ] Archive includes PrivacyInfo.xcprivacy and its required-reason API declaration
- [ ] Privacy report reflects the distributed app; the website policy distinguishes on-device questions from traced Worker API turns
- [ ] Save failures preserve editor input and never show false success
- [ ] Store initialization failures preserve existing data, and **Get help** opens the [same support page](https://pourstl.com/support) as Settings

## Native verification
- Use the GitHub-hosted macOS workflows for repeatable unit/UI tests and screenshots
- Boot the simulator, complete the personal testing checklist, and record the tested commit
- Verify physical camera, lifecycle and accessibility behavior on an iPhone
- If another coding assistant is available, keep its review evidence separate from executed tests
- Push fixes and re-test the changed behavior

Log all completions in COORDINATION.md and GitHub commits.
