#!/usr/bin/env bash
# Archive PourSTL, upload it to TestFlight, wait for processing, and assign it
# to an internal beta group. Requires macOS with Xcode and the secrets documented
# in docs/TESTFLIGHT.md.
set -euo pipefail
cd "$(dirname "$0")/.."

beta_group="App Store Connect Users"
build_number=""
check_only=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-only)
      check_only=true
      shift
      ;;
    --beta-group)
      beta_group="${2:?Missing beta group name}"
      shift 2
      ;;
    --build-number)
      build_number="${2:?Missing build number}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -n "$build_number" && ! "$build_number" =~ ^[1-9][0-9]*$ ]]; then
  echo "Build number must be a positive integer, got: $build_number" >&2
  exit 2
fi
for variable in ASC_KEY_ID ASC_ISSUER_ID ASC_PRIVATE_KEY APPLE_TEAM_ID; do
  if [[ -z "${!variable:-}" ]]; then
    echo "Missing required environment variable: $variable" >&2
    exit 1
  fi
done
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is required; run this on macOS with Xcode installed." >&2
  exit 1
fi
if ! sdk_version="$(xcrun --sdk iphoneos --show-sdk-version)" || ! [[ "$sdk_version" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || (( ${sdk_version%%.*} < 26 )); then
  echo "TestFlight requires an iOS 26 or later SDK. Select Xcode 26 or later." >&2
  exit 1
fi
xcodebuild -version
echo "Using iOS SDK $sdk_version"

workdir="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/pourstl-testflight.XXXXXX")"
chmod 700 "$workdir"
cleanup() {
  # Remove only the private temporary directory created above; it contains the API key.
  if [[ -n "${workdir:-}" && "$workdir" == *pourstl-testflight.* ]]; then
    rm -rf -- "$workdir"
  fi
}
trap cleanup EXIT
key_dir="$workdir/private_keys"
mkdir -p "$key_dir"
chmod 700 "$key_dir"
key_path="$key_dir/AuthKey_${ASC_KEY_ID}.p8"
export ASC_KEY_DIR="$key_dir"
export ASC_REWRITE_KEY=1

# Resolving the number checks the app record and materializes AuthKey. Xcode
# uses the same key file for signing, provisioning, and the upload export.
python3 scripts/app_store_connect.py check-app --bundle-id bar.pourstl.app --beta-group "$beta_group"
build_number="$(python3 scripts/app_store_connect.py resolve-build-number --bundle-id bar.pourstl.app --build-number "$build_number")"
echo "Using TestFlight build number $build_number"
if [[ "$check_only" == "true" ]]; then
  echo "TestFlight setup check complete. No build was archived or uploaded."
  exit 0
fi

export_options="$workdir/ExportOptions.plist"
python3 - "$APPLE_TEAM_ID" "$export_options" <<'PY'
import plistlib
import sys

team_id, path = sys.argv[1:]
plistlib.dump({
    "method": "app-store-connect",
    "destination": "upload",
    "teamID": team_id,
    "signingStyle": "automatic",
    "uploadSymbols": True,
    "testFlightInternalTestingOnly": True,
    "manageAppVersionAndBuildNumber": False,
}, open(path, "wb"))
PY

archive_path="$workdir/PourSTL.xcarchive"
export_path="$workdir/export"
mkdir -p "$export_path"

# Archives must be signed, but archive-time development profiles require a
# registered device. Use an ad-hoc intermediate signature; export re-signs for
# App Store distribution with cloud-managed signing assets.
xcodebuild archive \
  -project PourSTL.xcodeproj \
  -scheme PourSTL \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$archive_path" \
  CURRENT_PROJECT_VERSION="$build_number" \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
  CODE_SIGN_IDENTITY=- \
  AD_HOC_CODE_SIGNING_ALLOWED=YES \
  -allowProvisioningUpdates \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  -authenticationKeyPath "$key_path"

xcodebuild -exportArchive \
  -archivePath "$archive_path" \
  -exportOptionsPlist "$export_options" \
  -exportPath "$export_path" \
  -allowProvisioningUpdates \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  -authenticationKeyPath "$key_path"

python3 scripts/app_store_connect.py wait-and-assign \
  --bundle-id bar.pourstl.app \
  --build-number "$build_number" \
  --beta-group "$beta_group" \
  --internal \
  --create-group

echo "TestFlight upload complete: build $build_number assigned to $beta_group"
