# Pour

**Pour** is a native iOS bartender's assistant — a fast, offline-first recipe, inventory, and service tool for working bartenders.

Dark-mode-first SwiftUI app with a copper-accented design system, seeded with ~30 classic cocktails, intelligent "what can I make" inventory matching, professional scaling/batch mode, shopping list, timers, and custom recipes.

## Requirements

- Xcode 16.4 or newer with an installed iOS Simulator runtime (CI records the selected Xcode in the build manifest)
- iOS 17.0+ deployment target
- iPhone simulator or device

## Run it

```bash
open Pour.xcodeproj
# or build for the simulator:
xcodebuild -scheme Pour -destination 'platform=iOS Simulator,name=iPhone 17' build
# run tests:
xcodebuild -scheme Pour -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Then choose a simulator/device in Xcode and press ⌘R.

The dependency-free marketing site runs on Linux or macOS with
`python3 -m http.server 8080 --directory website`. It is separate from the native
app. VS Code includes a local website-server launch configuration.

Cloudflare Pages is the production host. The project name is **barpour** and the
public address is **https://barpour-7hb.pages.dev**. See
[website/README.md](website/README.md) for the project settings and build.

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

GitHub Actions runs the website checks and native unit tests on pushes to `main`
and `codex/**`, and on pull requests. A successful run includes a downloadable
**Pour-Simulator** artifact: a universal Release simulator app, commit/build
manifest, checksum, and installation guide. A separate **Simulator QA pass**
workflow records current UI tests and screenshots. See
[docs/PERSONAL_TESTING.md](docs/PERSONAL_TESTING.md) for installation and the
personal testing checklist. These unsigned builds require a Mac with Xcode;
physical iPhone installation and TestFlight need Apple provisioning/signing.

## Feature status

### Implemented (free-tier core)

- SwiftData persistence (recipes, ingredient lines, inventory, shopping list, venues, favorites)
- ~30 seeded classic cocktails with measures in oz, dashes, parts, barspoons, countables
- Home: real-time recipe search across name/ingredient/tag, filter chips, "What can I make" module driven by inventory, drink-card grid, pull-to-refresh
- Recipe detail: right-aligned monospaced measures, sticky action bar (favorite / scale / timer / share), serving scaling + batch mode, oz ⇄ ml conversion incl. dashes and barspoons, per-recipe unit toggle, one-tap "add missing to shopping list"
- My Bar: categorized inventory, in/out-of-stock toggles, low-stock flag, search, quick-add missing recipe ingredients, barcode scan with confirm-before-add
- Barcode scan stays on device: camera when the device allows it, a small offline bottle catalog, manual code entry when the camera is missing or denied, and the existing add-item sheet plus ingredient normalization when a code is unknown
- Shopping list with purchased tracking
- Local venues: create a venue, check in/out, and persist the selected workplace
- Custom recipe editor with glass-type picker mapped to SF Symbols
- Timer view: large circular progress ring, haptic ticks at 10s/5s/done
- Settings: manual dark/light/system appearance (persisted), preferred measurement unit (oz/ml) applied app-wide
- Ingredient normalization: local alias map ("London Dry Gin", "Beefeater" → gin) powering matching, "What can I make", and search
- Empty / error states throughout; everything works fully offline
- XCTest coverage for unit conversion, ingredient normalization, recipe/data integrity, barcode parsing/catalog/confirm/add/camera availability, assistant responses, and StoreKit entitlement/purchase/restore behavior
- `pour://` deep links (`pour://recipe?name=Negroni`, `pour://tab/bar`) as seams for future App Intents
- Bar Assistant: free offline recipe and inventory helper with supported question patterns, scaled measures, and ingredient stand-ins. Questions clear when the sheet closes; no model or remote AI service is used. Availability checks ingredient presence, not quantities or dietary suitability.
- Pour Pro upsell using StoreKit 2. The shared Pour scheme loads `Pour.storekit` so purchase, restore, and entitlement checks run locally. Placeholder product IDs live in `Pour/Services/ProProductID.swift`: `com.devin.pour.pro.monthly` and `com.devin.pour.pro.yearly`. Recipes, inventory, shopping, timers, barcode scanning, and venue check-in stay free with no purchase and no network. Live App Store products are not registered.

### Planned (out of scope for this build)

- CloudKit sync, Sign in with Apple. Charging customers still needs Apple Developer enrollment and App Store Connect products; the local StoreKit configuration does not create those.
- Voice search (Speech framework), agentic commands
- Live Activities / widgets
- AI video generation, venue QR onboarding, shift/team workflows, inventory costing/export

## Accessibility checklist (spot-checked per spec)

- All interactive elements carry explicit `accessibilityLabel`s reflecting state; buttons use `.isButton` (+ `.isSelected` where applicable)
- Measures use `.monospacedDigit()`; rows ≥ 52pt; touch targets ≥ 44pt
- Copper accent `#E8A87C` on `#0A0A0C` background passes WCAG AA for large text/icons
- Status is never color-only (icons + labels); decorative symbols are `accessibilityHidden`
- Reduce Motion respected on the timer ring and card presses

## Project layout

```
Pour/
  App/            entry point, root tab view, deep-link router
  Design/         palette, typography, glass→SF Symbol mapping
  Models/         SwiftData models
  Services/       conversion, normalization, matching, seeding, haptics, settings
  Features/       Home, Recipes, MyBar, Shopping, Timer, Assistant, Settings, stubs
PourTests/        XCTest unit tests
project.yml       XcodeGen spec (regenerate with `xcodegen` if needed)
```

## Browser testing

Open `try.html` from the local website server to test six classic recipes,
inventory matching, scaling, and shopping/restocking. The demo saves only in
that browser and has a Reset demo action. It does not share state with the
iPhone app or replace native-device testing.
