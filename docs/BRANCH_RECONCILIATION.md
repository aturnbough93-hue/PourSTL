# Branch reconciliation — November 12, 2026

The user requested completion of open pull requests and reconciliation of every
existing branch. All 24 non-main branch heads were inspected against main
`fc2823f`. The current integration branch includes the feature PR heads through
normal merges, conflict resolutions, and follow-up fixes/tests. Older heads
whose useful changes already exist or have been superseded are recorded as merge
parents while retaining the reviewed current tree. No branch is deleted.

The old revert branch would delete the native app and is deliberately superseded.
Older website variants would restore retired copy, assets or Netlify assumptions.
Their active improvements already exist in the current app/site. Two useful
legacy improvements were retained explicitly: plural bar-unit aliases and a
cancellable shopping confirmation reset. Existing startup error propagation,
canonical shopping deduplication, safe save/rollback, and cold-start deep links
are retained.

| Branch | Audited head | Disposition |
| --- | --- | --- |
| `app-beta-version` | `a97ad6f2497e` | Superseded implementation; useful fixes retained, history reconciled without regressing current tree |
| `aturnbough93-hue-pour-app` | `a97ad6f2497e` | Superseded implementation; useful fixes retained, history reconciled without regressing current tree |
| `codex/native-polish-transfer` | `663f9307c23c` | Equivalent/squashed changes already present; history reconciled with current tree retained |
| `codex/native-release-test` | `fba2e4a4bcbe` | Already included in main history |
| `codex/review-improvements` | `6eb88d2d4094` | Already included in main history |
| `codex/web-demo-transfer` | `bdb344177156` | Equivalent/squashed changes already present; history reconciled with current tree retained |
| `copilot/check-and-resolve-code-issues` | `4f91140db254` | Superseded implementation; useful fixes retained, history reconciled without regressing current tree |
| `copilot/check-and-resolve-code-issues-again` | `7c037f17fdbf` | Superseded implementation; useful fixes retained, history reconciled without regressing current tree |
| `copilot/remote` | `d204fcf874c3` | Already included in main history |
| `cursor/ai-bartender-assistant-cc8d` | `f4d17b0eddc6` | Normal feature/history merge; reviewed and corrected in integration |
| `cursor/barcode-scanning-2cba` | `f189fa7a11b7` | Normal feature/history merge; reviewed and corrected in integration |
| `cursor/iphone-safari-menu-dismiss-5f4c` | `82faa7d5a1ee` | Equivalent/squashed changes already present; history reconciled with current tree retained |
| `cursor/launch-screen-brand-colors-274b` | `42b94cd04af7` | Equivalent/squashed changes already present; history reconciled with current tree retained |
| `cursor/pages-dev-site-url-ef1b` | `5360adbfd6c3` | Equivalent/squashed changes already present; history reconciled with current tree retained |
| `cursor/parked-homepage-polish-8a3c` | `b292cabc277b` | Equivalent/squashed changes already present; history reconciled with current tree retained |
| `cursor/pour-pro-storekit-6e5c` | `6525965a9865` | Normal feature/history merge; reviewed and corrected in integration |
| `cursor/remove-netlify-hosting-d1a5` | `f5a8834b0857` | Equivalent/squashed changes already present; history reconciled with current tree retained |
| `cursor/root-apple-touch-icon-5c4c` | `73bee33c0794` | Normal feature/history merge; reviewed and corrected in integration |
| `dependabot/github_actions/actions/checkout-7.0.1` | `e76d1df55d9d` | Equivalent/squashed changes already present; history reconciled with current tree retained |
| `devin/1793359749-pour-app` | `7c037f17fdbf` | Superseded implementation; useful fixes retained, history reconciled without regressing current tree |
| `devin/1793360139-pour-website` | `d204fcf874c3` | Already included in main history |
| `qa/pr10-simulator-pass` | `7c405f1d1f37` | Normal feature/history merge; reviewed and corrected in integration |
| `revert-1-devin/1793359749-pour-app` | `0c444c899d60` | Superseded implementation; useful fixes retained, history reconciled without regressing current tree |
| `website-version` | `65ff9cc743e8` | Already included in main history |

The final release PR and CI runs provide validation for the integrated tree.
Branch reconciliation records ancestry; it does not claim every historical
implementation is the chosen source or has separately passed current tests.
