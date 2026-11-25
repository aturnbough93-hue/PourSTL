# PourSTL 1.0 App Store listing draft

- **Name** — PourSTL
- **Subtitle** — Cocktail recipes & bar prep
- **Primary category** — Food & Drink
- **Keywords** — cocktails, bartender, mixology, drinks, recipes, bar inventory, batch, costing, timer
- **Support URL** — https://pourstl.com/support
- **Privacy policy URL** — https://pourstl.com/privacy
- **Marketing URL** — https://pourstl.com/
- **Terms of Use** — Apple’s standard end-user license agreement

## Description

Find a classic to make with the bottles you already have. PourSTL gives home bartenders and working bars cocktail recipes, a personal inventory, and tools to get drinks ready for service.

**Free** includes the recipe library, custom recipes and favorites, barcode and manual inventory entry, ingredient matching, shopping lists, haptic timers, and the offline Bar Assistant. Scale recipes up to 24 servings and switch between ounces and milliliters.

**PourSTL Pro** adds ingredient cost estimates per drink and per batch, batch scaling up to 200 servings, and CSV prep sheets. Enter package prices and measured yields to reuse them across your recipes. Export scaled quantities, optional ingredients, and ingredient notes when you’re planning an event or sharing prep with your crew.

PourSTL keeps recipes, bar inventory, and ingredient prices on your iPhone. An account is unnecessary. Pro subscriptions are purchased and managed through the App Store.

## App Review notes draft

- The main tools are available immediately after onboarding. From Home, open a classic recipe to try scaling, sharing and the timer. My Bar supports manual entry and camera-based barcode scanning.
- In a recipe, scroll to **Costing & Batch Prep** to open the Pro subscription screen. Existing subscribers can restore from **Settings → PourSTL Pro → Restore purchases**. Once Pro is active, open the recipe again to set a batch size, enter a package price and yield, and export the CSV to Files.
- The app’s bundle identifier is `bar.pourstl.app`. The planned monthly and yearly product IDs are `bar.pourstl.app.pro.monthly` and `bar.pourstl.app.pro.yearly`. Confirm the owner’s App Store Connect record and prices before submission. Xcode’s local StoreKit fixture is separate from the live products.

## Before submission

- Capture screenshots from the signed candidate showing Home and My Bar, a scaled recipe, and Pro costing and batch prep. Verify Apple’s screenshot requirements for the selected devices.
- Confirm the age-rating questionnaire for alcohol references, export compliance, privacy answers, support contact, build number, and the legal URLs in App Store Connect.
- Verify purchase, restore and expiration on Apple’s sandbox using the configured products. Verify barcode scanning, haptics and accessibility on a physical iPhone.
- For Andrew’s direct install, use a registered iPhone and an ad hoc provisioning profile with the matching distribution signing identity. See [Apple’s ad hoc provisioning instructions](https://developer.apple.com/help/account/provisioning-profiles/create-an-ad-hoc-provisioning-profile/) and [the testing guide](PERSONAL_TESTING.md).
