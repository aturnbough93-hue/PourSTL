# Pour product, code, UI, and security review

Reviewed November 5, 2026. Scope: checked-in SwiftUI/SwiftData app, XCTest source,
Xcode project, static website, development configuration, and Git history.

## Assessment

Pour has a useful, focused offline core: classic recipes, ingredient matching,
inventory, scaling, shopping, favorites, and a timer. Keep the dark surfaces,
warm copper, explicit stock states, and readable measures. Reliability and a
short path from buying ingredients to making drinks matter more to this product
than adding more placeholder buttons.

The website is a marketing site with illustrative app mockups, not a web version
of the app. The native app still needs simulator, archive, signing, and release
validation before an App Store or TestFlight release.

## Fixes included

| Area | Finding | Change |
| --- | --- | --- |
| Data integrity | Save errors were ignored and some flows dismissed or signaled success | Explicit saves, error alerts, rollback, and retained editor input; seed fetch errors propagate instead of being treated as an empty store |
| Shopping | Repeated missing-ingredient additions duplicated canonical ingredients | Deduplicate pending ingredients and aliases; purchased history does not prevent buying again |
| Workflow | Checking a purchase did not connect it to inventory | Explicit **Stock bar** action restocks the matching item or creates it |
| Discovery | Availability was shown without an effective library filter | **Can make** and **Almost there** filters; clear-filter empty states |
| Recipes | Negative, zero, and nonfinite quantities could be saved | Require finite positive quantities, with zero allowed for top-ups and rinses |
| Routing | Recipe links could navigate inside an inactive tab or before seeding | Switch to Home and resolve pending links when recipes become available |
| Timer | 90 seconds displayed as 1 minute; completion looked ready again | Exact preset labels and a persistent **Complete** state |
| Accessibility | Shared fixed-size typography and narrow grids constrained large text | Semantic fonts, one-column accessibility grid, larger targets, reduced-motion filter animation |
| Privacy | UserDefaults had no required-reason manifest | Bundle a privacy manifest declaring app-only preferences (`CA92.1`) |
| Permissions | Unimplemented voice/scanning features declared usage descriptions | Remove unused camera/microphone/speech descriptions from both project sources |
| Trust | Placeholder support email and ambiguous download/Pro claims | GitHub feedback, honest development status, labeled mockups and planned features |
| Website | Mobile navigation trapped focus; tiny screens and muted text needed work | Disclosure navigation with Escape/Tab/outside-click/resize handling, responsive sizing, stronger contrast |
| Website security | No application security header policy | Netlify CSP, no framing, nosniff, restricted device permissions, and referrer policy |
| Developer experience | VS Code and Dependabot targeted nonexistent workflows | Static-server launch configuration, GitHub Actions updates, website checks and macOS CI |

## Security and privacy review

No app runtime networking, authentication backend, WebView, analytics SDK, or
third-party package dependency was found. Deep links select local tabs/recipes;
they do not execute commands or import remote data. No high-severity exploitable
vulnerability was established in this review.

A heuristic scan of 37 commits and 84 unique Git blobs found no matches for
common GitHub/AWS/OpenAI credentials, private keys, or credential assignments.
This is not a guarantee that the repository contains no sensitive information.

The website loads local assets and a local navigation script. The CSP prohibits
remote connections, inline scripts, embedded objects, forms, and framing. Inline
styles remain allowed because the current dependency-free design uses them.
Hosting logs and outbound GitHub visits are distinct from app data collection.
The privacy page explains sharing, device backups, and these limits.

## Remaining release work

| Priority | Work | Acceptance evidence |
| --- | --- | --- |
| P0 | Validate native changes on macOS | Successful simulator build and all XCTest results; real-device smoke test |
| P0 | Add a production AppIcon asset catalog | Icon appears on device and passes archive validation |
| P0 | Set the owner's final bundle/signing identity and support metadata | Signed archive, privacy report, App Store Connect validation |
| P1 | Recover safely from persistent-store initialization failures | Informative recovery UI; preserve database; no automatic destructive reset |
| P1 | Export/restore and versioned data migrations | Round-trip inventory/custom recipe backup and migration fixtures |
| P1 | Device accessibility QA | VoiceOver, AX5 text, light/dark, Reduce Motion, one-handed use; no clipping |
| P1 | Clarify foreground-only timer behavior | Test lock/background/return; add permission-based local alerts if needed |
| P2 | Consolidate coming-soon tools into one roadmap surface | Primary controls all perform useful work; planned tools remain discoverable |

## Recommended additions, in delivery order

1. **Service confidence:** undo deletion, recipe duplication as a house variation,
   backup/export/import, and reliable storage recovery. Add a short success state
   after stocking a purchase so the new inventory connection is easy to learn.
2. **Smarter shopping:** show which one missing ingredient unlocks the most drinks;
   allow quantity/pack notes and sharing a shopping list. Ingredient-presence
   matching currently does not verify amounts, substitutions, or allergens.
3. **Better batch prep:** dilution guidance with explicit assumptions, prep lists,
   separate garnish quantities, and saved batch sizes. Keep native bar measures
   rather than silently converting every unit into milliliters.
4. **Professional operations:** bottle-level stock/costs, margins, venue-specific
   specs, and shift checklists. Design quantity-aware matching before claiming
   inventory can fulfill a batch.
5. **Optional connected features:** backup/sync and team roles first, then barcode
   and voice. Add AI only with explicit data-sharing choices, visible assumptions,
   and a useful offline fallback. Keep the free working core independent.

## Validation boundaries

Linux can serve and browser-test the website and validate project metadata, but
cannot run the iOS SDK, SwiftUI, SwiftData, XCTest, VoiceOver, haptics, or signing.
Five new native regression tests are included; do not count them as passed until
the macOS workflow completes. Local security-header tests do not establish that
Netlify has deployed them. Publication and live-domain validation must be
reported separately from local checks.
