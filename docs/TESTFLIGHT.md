# TestFlight launch setup

This repository now has a manual TestFlight upload path in [`testflight.yml`](../.github/workflows/testflight.yml). It uses plain `xcodebuild` and a small dependency-free App Store Connect API client; it does **not** use fastlane Match or require a separate certificate repository.

The first launch target is **internal TestFlight** from `main` after all release-blocking pull requests are merged. App Store metadata is drafted in `appstore/`, but Pro subscription prices are intentionally undecided.

## What the automation does

`scripts/testflight_upload.sh`:

1. verifies the `bar.pourstl.app` app record exists;
2. materializes the App Store Connect `.p8` key in a private temporary directory;
3. uses the latest App Store Connect build number + 1, or checks that a supplied number is higher;
4. archives the Release app with `CURRENT_PROJECT_VERSION` overridden for that archive only, using an ad-hoc intermediate signature so no registered device is needed;
5. re-signs for App Store distribution with cloud-managed automatic signing and uploads a TestFlight Internal Only build using the API key;
6. polls until the uploaded build is `VALID`;
7. finds the internal beta group (default `App Store Connect Users`), creates a missing custom group when necessary, and assigns the build unless the group already receives all builds.

`project.yml` still contains the repository baseline build number. The upload-time override keeps App Store Connect numbers monotonic without requiring a commit for every upload.

## Account-holder steps that cannot be completed from the repository

Do these in the Apple account before running the workflow:

1. **Agreements.** Sign in to App Store Connect and accept current Apple Developer agreements. For meaningful In-App Purchase testing, also complete the Paid Apps agreement plus tax and banking information.
2. **Register the App ID.** In the Apple Developer portal, create an explicit iOS App ID:
   - Description: `PourSTL`
   - Bundle ID: `bar.pourstl.app`
   - Capabilities: leave optional capabilities off; normal In-App Purchase is automatic for explicit App IDs.
   - Do not enable Push Notifications, iCloud/CloudKit, Sign in with Apple, App Groups, Associated Domains, Game Center, NFC, Background Modes, Apple Pay, MusicKit, ShazamKit, WeatherKit, or external-purchase entitlements.
3. **Create the app record manually.** Apple's public API does not create initial app records. In App Store Connect choose:
   - Platform: iOS
   - Name: `PourSTL`
   - Primary language: English (U.S.) unless Andrew chooses otherwise
   - Bundle ID: `bar.pourstl.app`
   - SKU: `pourstl-ios` unless Andrew chooses otherwise
4. **Prepare internal testers.** Internal TestFlight testers must already be App Store Connect team users. Add the intended people under Users and Access, then enable them as internal testers. The automation uses the built-in `App Store Connect Users` group by default and can create a missing custom group, but it does not invent tester accounts.
5. **Set TestFlight beta information.** In App Store Connect, set the beta feedback email and review/copy the files in `appstore/testflight/`. Internal builds do not require external beta review, but the feedback contact still needs a real mailbox.
6. **Create an App Store Connect API key.** Create a team key, normally with the App Manager role. Download the `.p8` immediately; Apple offers the download only once. Record the Key ID and Issuer ID. If signing asset creation later fails specifically because of key permissions, regenerate/use a key with Admin access rather than weakening repository security.
7. **Store secrets securely.** Add these GitHub Actions repository secrets (or the equivalent Devin secrets for a trusted macOS session). Never commit or paste them in chat:
   - `ASC_KEY_ID`
   - `ASC_ISSUER_ID`
   - `ASC_PRIVATE_KEY` — the complete `.p8` PEM contents, including its BEGIN/END private-key boundary lines
   - `APPLE_TEAM_ID`

## Upload from GitHub Actions

After the secrets and manual Apple records exist:

1. Open **Actions → TestFlight upload → Run workflow**.
2. Run it from `main` once release-blocking PRs are merged.
3. Leave **build_number** blank for automatic numbering.
4. Use beta group `App Store Connect Users` unless Andrew chooses another internal group.
5. Wait for the workflow to finish. The final log line reports the App Store Connect build number and beta-group assignment.

The upload job runs only from `main` on manual dispatch with `contents: read`.
It selects Xcode 26.3 on the `macos-15` runner to meet Apple's iOS SDK
requirements. TestFlight Internal Only builds can be distributed to internal
tester groups. See Apple's [upload requirements](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)
and [internal tester setup](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/).

## Upload from a trusted macOS session

Use a trusted Mac with Xcode 26 or later selected and the iOS SDK installed:

```bash
export ASC_KEY_ID='...'
export ASC_ISSUER_ID='...'
export ASC_PRIVATE_KEY="$(cat /secure/path/AuthKey_KEYID.p8)"
export APPLE_TEAM_ID='...'
bash scripts/testflight_upload.sh --beta-group 'App Store Connect Users'
```

A fixed positive integer can be supplied with `--build-number N`, but blank automatic numbering is preferred.

## App metadata and subscriptions

Canonical draft copy lives in:

- `appstore/metadata/en-US/` — name, subtitle, keywords, description, URLs, and release notes;
- `appstore/testflight/` — beta description and What to Test;
- `appstore/subscriptions/README.md` — draft subscription group/product metadata.

Pro subscription products must use the IDs in `PourSTL/Services/ProProductID.swift`:

- `bar.pourstl.app.pro.monthly`
- `bar.pourstl.app.pro.yearly`

For the first internal TestFlight launch, create them as drafts only if desired. Do not choose final prices, free trials/introductory offers, or Family Sharing without Andrew's explicit decision.

## Required manual release evidence

Automation does not replace the release checklist. Before treating a build as launch-ready, complete `BETA_CHECKLIST.md` with evidence for the exact build, including:

- physical iPhone camera, lifecycle, haptics, and accessibility checks;
- VoiceOver, Dynamic Type, contrast, touch-target, and Reduce Motion checks;
- purchase, restore, expiration, and relaunch behavior with App Store Connect/sandbox products;
- privacy nutrition labels and the alcohol-related age-rating questionnaire;
- fresh screenshots generated from the final release candidate, not historical `qa/screenshots` files;
- deployed support/privacy/marketing URL verification.

`Info.plist` already sets `ITSAppUsesNonExemptEncryption` to `false` for the app's current exempt/standard encryption use. Reassess that answer if non-exempt encryption is ever added.

## Troubleshooting

- **`No App Store Connect app record exists`** — create the app record manually first.
- **Authentication/authorization errors** — verify the key ID, issuer ID, team ID, complete `.p8` text, key role, and accepted agreements.
- **Signing or provisioning errors** — verify the explicit App ID and bundle ID exactly match `bar.pourstl.app`; if the API key cannot create signing assets, use an Admin-role key.
- **Build number errors** — leave the input blank and let the script choose latest + 1.
- **No testers receive the build** — confirm they are App Store Connect users, enabled as internal testers, and members of the selected internal group.
- **Purchases are unavailable** — confirm Paid Apps/tax/banking status and that the subscription products exist with the exact product IDs. Draft or incomplete products may not behave like purchasable products.
