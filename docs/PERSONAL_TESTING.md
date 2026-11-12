# Test Pour

Share the live website at **https://barpour.pages.dev**. The interactive browser demo at **https://barpour.pages.dev/try.html** works on a phone or computer. It saves data in that browser; it does not install or sync with the native app.

## Download the native simulator app

A Mac with Xcode and an installed iOS Simulator runtime is required. This is an unsigned **iOS Simulator** app, not an iPhone installation or TestFlight build.

1. Open [Quality checks in GitHub Actions](https://github.com/aturnbough93-hue/pour/actions/workflows/ci.yml), choose the successful run for the commit you want to test, and download **Pour-Simulator** from Artifacts. GitHub may require sign-in and repository access.
2. Extract the artifact. It contains `Pour-Simulator.zip`, `build-manifest.json`, and this guide. The manifest records the source commit, Release configuration, native platform, minimum OS, SDK, Xcode version, test counts, archive SHA-256, and actual architectures. The archive supports Apple Silicon (`arm64`) and Intel (`x86_64`) simulators.
3. On the Mac, open Xcode → Settings → Components and install an iOS runtime at least as new as `minimumOSVersion` in the manifest. Prefer the runtime used by that run's Xcode. Open Simulator and boot an iPhone.
4. In Terminal, change to the extracted artifact directory, verify and extract the app, then install it:

   ```bash
   python3 - <<'PY'
   import hashlib, json
   from pathlib import Path
   manifest = json.loads(Path('build-manifest.json').read_text())
   digest = hashlib.sha256(Path('Pour-Simulator.zip').read_bytes()).hexdigest()
   assert digest == manifest['archiveSHA256'], 'Archive checksum does not match'
   assert manifest['nativePlatform'] == 'iPhoneSimulator'
   print('Testing commit', manifest['sourceCommit'])
   print('Architectures:', ', '.join(manifest['architectures']))
   PY
   ditto -x -k Pour-Simulator.zip .
   xcrun simctl list devices booted
   xcrun simctl install booted Pour.app
   xcrun simctl launch booted com.devin.pour
   ```

   If several simulators are booted, replace `booted` with the selected device's UDID from the list. If you see an architecture/runtime error, check the manifest and select a compatible simulator. Simulator apps cannot be opened directly on macOS.

The downloadable Release app follows normal onboarding and saves data between launches. Automated test flags are disabled in Release. To reset the simulator app, use `xcrun simctl uninstall booted com.devin.pour` and reinstall; this deletes that simulator's Pour data. To update without resetting, install the new app over the old one.

The Release artifact does not carry Xcode's local StoreKit session. Subscription prices may be unavailable there until real App Store products exist. The free recipe, inventory, shopping, and timer functions remain usable.

## Run the app and billing tests from source

1. Check out the desired commit and open `Pour.xcodeproj` in Xcode.
2. Select the **Pour** shared scheme and an iPhone simulator, then Run. The project's minimum deployment target is iOS 17; use Xcode compatible with the project's Swift and installed SDK.
3. For local subscription testing, edit the scheme → Run → Options and confirm **StoreKit Configuration = Pour.storekit**. Use Debug. Local StoreKit transactions are simulated; they do not create App Store products or charge a payment method.
4. Use Xcode's StoreKit transaction manager to clear transactions, test purchase/cancellation/restore/expiration, and confirm Pro status updates. Keep ordinary free workflows usable before any purchase. If testing outside a local StoreKit session, cancel unexpected payment/account prompts and establish the intended Apple sandbox configuration first.

The **PourQA** scheme uses the same local configuration for automated UI tests. Its smoke test opens and dismisses the Pro sheet without tapping purchase or restore. This validates navigation, not the complete billing lifecycle. StoreKit unit tests exercise local transactions separately.

Reproduce CI on a Mac with Xcode:

```bash
bash scripts/test_ios.sh
bash scripts/qa_simulator_pass.sh
```

The first script runs unit tests and builds a universal Release simulator archive, with a manifest and checksum. The second runs unit and UI tests serially on an available iPhone 16 Pro Max or iPhone 17 Pro Max simulator and produces eight 1320×2868 testing screenshots plus a checklist. Both fail when tests are missing or failing. They print artifact locations; repeated runs keep separate output folders.

Download **qa-simulator-pass** from the [Simulator QA pass workflow](https://github.com/aturnbough93-hue/pour/actions/workflows/qa-simulator-pass.yml) for the **same commit** as the app artifact. Its `qa-results.md`, `PourQA.xcresult`, test summary, build log, and screenshots show the checks actually performed. CI artifact retention is 14 days for the app and QA package. Images checked into `qa/screenshots` came from an older barcode QA run; use current run artifacts as evidence for the current app.

## Test on a physical iPhone

There is no signed iPhone installer in the simulator artifact. To install directly, connect an iPhone to a Mac, enable Developer Mode if prompted, select it in Xcode, set a development team in Signing & Capabilities, and Run the **Pour** scheme. Use a team and bundle identifier provisioned for that device. Xcode's free Personal Team provisioning has device/capability and expiration limits; Apple documents the current limits in Xcode.

For testers who do not have Xcode, use TestFlight after an Apple Developer team, App Store Connect app, distribution signing, and an uploaded build are configured. A successful simulator build does not complete those steps. Live purchases additionally need actual App Store Connect products and Apple sandbox testing; the repository's local product configuration does not register them.

## Personal testing checklist

Record the commit from `build-manifest.json` or Xcode, device model, OS version, exact steps, expected/actual behavior, and a screenshot when reporting a problem. Use sample data while testing and verify persistence before relying on stored inventory.

- Complete onboarding, browse/search classics, favorite a recipe, and verify favorites after relaunch.
- Add bottles to My Bar, toggle in-stock and low-stock states, and confirm “What can I make” changes. Matching checks ingredient availability, not remaining bottle quantities.
- Open a recipe, scale servings, switch oz/ml, start/pause/reset the timer, share a recipe, and add missing ingredients to Shopping. Add/delete shopping items and check persistence after relaunch.
- Make a variation of a classic, save it, and confirm the original is unchanged. Create/edit a custom recipe and confirm it persists.
- Open **More features → Bar Assistant** and try the starter questions. It is an offline helper for supported question patterns, not a general AI model. Verify responses against the recipe; it does not assess allergies or alcohol safety.
- Change appearance and preferred units. Try larger text and VoiceOver, and verify controls remain usable.
- On a physical iPhone, test the camera permission prompt, allow/deny/Settings return, known and unknown barcodes, ambiguous eight-digit codes, duplicate prevention, cancel-and-rescan, torch, rotation, and background/foreground. Manual barcode entry is available when camera access is unavailable.
- On a physical iPhone, try airplane mode and timer behavior while backgrounded; simulator navigation tests do not establish camera or real device lifecycle behavior.
- In a local StoreKit session or established Apple sandbox, verify purchase cancellation, purchase, restore, revocation/expiration, and continued access to free features. Do not use live billing for personal QA.

Voice search, cloud sync, and App Store distribution are not delivered by the simulator build. The QA report explicitly marks physical-device work still required; a green simulator workflow does not imply launch or App Store approval.
