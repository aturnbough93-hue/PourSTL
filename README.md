# PourSTL

**PourSTL** is a bartending app with recipes, inventory, and service tools for working bartenders. The project includes a native iPhone app and [PourSTL Web](https://pourstl.com/try), which you can open in a browser without an account.

Dark-mode-first SwiftUI app with a copper-accented design system, seeded with ~30 classic cocktails, intelligent "what can I make" inventory matching, professional scaling/batch mode, shopping list, timers, and custom recipes.

## Requirements

- Xcode 16.4 or newer with an installed iOS Simulator runtime (CI records the selected Xcode in the build manifest)
- iOS 17.0+ deployment target
- iPhone simulator or device

## Run it

```bash
open PourSTL.xcodeproj
# or build for the simulator:
xcodebuild -scheme PourSTL -destination 'generic/platform=iOS Simulator' build
# run tests:
bash scripts/test_ios.sh
```

Then choose a simulator/device in Xcode and press ⌘R.

The dependency-free website and browser app run on Linux or macOS with
`python3 -m http.server 8080 --directory website`. They are separate from the
native app. VS Code includes a local website-server launch configuration.

Cloudflare Pages hosts project **pourstl**. The canonical site is
**https://pourstl.com**. See
[website/README.md](website/README.md) for the project settings and build.

The standalone [Cloudflare Bar Assistant Worker](workers/bar-assistant/README.md)
answers general bartending questions with Workers AI at
`POST https://assistant.pourstl.com/v1/assistant/turn`. It requires a bearer
token and is deployed separately from Cloudflare Pages. Neither the iPhone app
nor PourSTL Web calls it, and it has no access to their local data. Cloudflare
Agent Tracing is configured to capture every AI turn, including the question
and answer.

See [docs/HANDOFF.md](docs/HANDOFF.md) for current delivery status and resuming work.
See [REVIEW.md](REVIEW.md) for the code, UI, security review, improvements included,
and prioritized release/product roadmap. Native changes must pass simulator and
device validation before distributing a build.

## Quality checks

```bash
python3 scripts/check_website.py
node scripts/test_demo.cjs
node --check website/site.js
# macOS with Xcode and an installed iOS 17+ iPhone simulator:
bash scripts/test_ios.sh
```

[Quality checks](.github/workflows/ci.yml) runs the website, Worker, and release
metadata checks alongside native unit tests on pushes to `main` and `codex/**`,
and on pull requests. A successful run includes a downloadable
**PourSTL-Simulator** artifact: a universal Release simulator app, commit/build
manifest, checksum, and installation guide. The separate
[Simulator QA pass](.github/workflows/qa-simulator-pass.yml) workflow records
current UI tests and screenshots. Before publishing, run
[Release checks](.github/workflows/release-checks.yml) on the exact candidate ref.
It reruns both workflows and checks the release build number; see the
[beta checklist](BETA_CHECKLIST.md#automated-release-checks) for triggers and
baseline rules. See [the personal testing guide](docs/PERSONAL_TESTING.md) for
installation and manual checks. These unsigned builds require a Mac with Xcode;
physical iPhone installation and TestFlight need Apple provisioning/signing.

## Feature status

### iPhone: Free

- SwiftData persistence (recipes, ingredient lines, inventory, shopping list, venues, favorites)
- ~30 seeded classic cocktails with measures in oz, dashes, parts, barspoons, countables
- Home: real-time recipe search across name/ingredient/tag, filter chips, "What can I make" module driven by inventory, drink-card grid, pull-to-refresh
- Recipe detail: right-aligned monospaced measures, sticky action bar (favorite / scale / timer / share), scaling up to 24 servings, oz ⇄ ml conversion incl. dashes and barspoons, per-recipe unit toggle, one-tap "add missing to shopping list". Unstocked required ingredients are marked **Missing**; optional ingredients show **Optional** or **Optional · not stocked**.
- My Bar: categorized inventory, in/out-of-stock toggles, low-stock flag, search, quick-add missing recipe ingredients, barcode scan with confirm-before-add. Categories appear in section headings, not on each row; an ingredient shows a matching alias when it differs from its normalized name (for example, London Dry Gin shows `gin`).
- Barcode scan stays on device: camera when the device allows it, a small offline bottle catalog, manual code entry when the camera is missing or denied, and the existing add-item sheet plus ingredient normalization when a code is unknown
- Shopping list with purchased tracking
- Local venues: create a venue, check in/out, and persist the selected workplace
- Custom recipe editor with glass-type picker mapped to SF Symbols
- Timer view: large circular progress ring, haptic ticks at 10s/5s/done
- Settings: manual dark/light/system appearance (persisted), preferred measurement unit (oz/ml) applied app-wide
- Settings → Support offers three browser links: [Get support](https://pourstl.com/support), [Privacy policy](https://pourstl.com/privacy), and [PourSTL website](https://pourstl.com). The store-recovery screen’s **Get help** opens the same support page.
- Ingredient normalization: local alias map ("London Dry Gin", "Beefeater" → gin) powering matching, "What can I make", and search
- Empty / error states throughout; local recipe and bar tools work offline
- XCTest coverage for unit conversion, ingredient normalization, recipe/data integrity, barcode parsing/catalog/confirm/add/camera availability, assistant responses, and StoreKit entitlement/purchase/restore behavior
- `pourstl://` deep links (`pourstl://recipe?name=Negroni`, `pourstl://tab/bar`); legacy `pour://` links remain supported
- Bar Assistant on iPhone: free, on-device rules for supported recipe and inventory questions, scaled measures, and ingredient stand-ins. Questions clear when the sheet closes; the app does not call the Worker. Availability checks ingredient presence, not quantities or dietary suitability.

### iPhone: Pro

- PourSTL Pro adds recipe costing with reusable package prices, estimated ingredient margins and suggested menu prices, scaling up to 200 servings, and CSV prep sheets with estimated dilution, batch yield, and a separate garnish section. Pro can also track bottle costs, quantities and low-stock alerts, estimate inventory value at cost, and suggest the single bottle that unlocks the most recipes. Price data stays on the device. The StoreKit 2 product IDs are `bar.pourstl.app.pro.monthly` and `bar.pourstl.app.pro.yearly`. The shared scheme uses `PourSTL.storekit` for local testing. Configure the matching products in App Store Connect before selling Pro.

### Planned (out of scope for this build)

- CloudKit sync, Sign in with Apple. Charging customers still needs Apple Developer enrollment and App Store Connect products; the local StoreKit configuration does not create those.
- Voice search (Speech framework), agentic commands
- Live Activities / widgets
- AI video generation, venue QR onboarding, shift/team workflows

## Accessibility checklist (spot-checked per spec)

- All interactive elements carry explicit `accessibilityLabel`s reflecting state; buttons use `.isButton` (+ `.isSelected` where applicable)
- Measures use `.monospacedDigit()`; rows ≥ 52pt; touch targets ≥ 44pt
- Copper accent `#E8A87C` on `#0A0A0C` background passes WCAG AA for large text/icons
- Status is never color-only (icons + labels); decorative symbols are `accessibilityHidden`
- Reduce Motion respected on the timer ring and card presses

## Project layout

```
PourSTL/
  App/            entry point, root tab view, deep-link router
  Design/         palette, typography, glass→SF Symbol mapping
  Models/         SwiftData models
  Services/       conversion, normalization, matching, seeding, haptics, settings
  Features/       Home, Recipes, MyBar, Shopping, Timer, Assistant, Settings, stubs
PourSTLTests/        XCTest unit tests
website/           static site and PourSTL Web (Cloudflare Pages)
workers/bar-assistant/  standalone Workers AI endpoint and deployment config
project.yml       XcodeGen spec (regenerate with `xcodegen` if needed)
```

## Browser testing

Open [PourSTL Web](https://pourstl.com/try) or use `/try.html` on the local server.
Use a Cloudflare Pages preview, not the local server, to test offline caching
and Home Screen installation.
Use the seeded catalog, save custom recipes and favorites, stock My Bar, and
manage a shopping list. The web app saves data in the browser, scales to 24
servings, and works offline after it caches the app. Open **Bar Assistant** in
the header for local recipe and inventory questions, ingredient stand-ins, and
scaled measures. Questions and replies clear when you close it. Pro tools are
iPhone-only.

In the web app, stocking `Rye` in My Bar counts as stocking rye whiskey for
recipe matching.

See the [website guide](website/README.md) for offline and deployment checks.
