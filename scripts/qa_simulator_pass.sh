#!/usr/bin/env bash
# GitHub-hosted iPhone simulator QA. No paid device farms, secrets, or third-party services.
set -euo pipefail
cd "$(dirname "$0")/.."

artifacts="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/pourstl-qa.XXXXXX")"
mkdir -p "$artifacts/screenshots"
touch "$artifacts/run-start"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  printf 'artifacts_directory=%s\n' "$artifacts" >> "$GITHUB_OUTPUT"
fi

select_device() {
  local sdk_version
  sdk_version="$(xcrun --sdk iphonesimulator --show-sdk-version)" || return 1
  python3 - "$sdk_version" <<'PY'
import json
import re
import subprocess
import sys

def version_parts(value):
    if not re.fullmatch(r"\d+(?:\.\d+){0,2}", value):
        raise SystemExit(f"Cannot parse iOS Simulator SDK version: {value}")
    return tuple((list(map(int, value.split("."))) + [0, 0])[:3])

sdk = version_parts(sys.argv[1])

devices = json.loads(subprocess.check_output(
    ["xcrun", "simctl", "list", "devices", "available", "--json"], text=True
))["devices"]
preferred = ["iPhone 17 Pro Max", "iPhone 16 Pro Max"]
found = []
for runtime, entries in devices.items():
    version = re.search(r"\.iOS-(\d+(?:-\d+)*)$", runtime)
    if not version:
        continue
    runtime_version = version.group(1).replace("-", ".")
    numbers = version_parts(runtime_version)
    if numbers[0] < 17 or numbers > sdk:
        continue
    for device in entries:
        if device.get("isAvailable") and device["name"] in preferred:
            found.append((numbers[:2] == sdk[:2], numbers, -preferred.index(device["name"]), device["udid"], device["name"], runtime_version))
if found:
    _match, _numbers, _priority, udid, chosen, runtime_version = max(found)
    print(f"{udid}\t{chosen}\t{runtime_version}\t{sys.argv[1]}")
    sys.exit(0)
print(f"No iPhone 17 Pro Max or iPhone 16 Pro Max runtime compatible with SDK {sys.argv[1]}.", file=sys.stderr)
for runtime, entries in devices.items():
    for device in entries:
        if device.get("isAvailable") and "iPhone" in device["name"]:
            print(f"{runtime} {device['name']}", file=sys.stderr)
sys.exit(1)
PY
}

selection=""
if selection="$(select_device 2>"$artifacts/simulators.txt")"; then
  :
else
  shopt -s nullglob
  for app in /Applications/Xcode*.app; do
    export DEVELOPER_DIR="$app/Contents/Developer"
    if selection="$(select_device 2>>"$artifacts/simulators.txt")"; then
      echo "Selected Xcode at $DEVELOPER_DIR"
      break
    fi
  done
fi

if [[ -z "$selection" ]]; then
  echo "Could not find a 6.9-inch iPhone simulator."
  cat "$artifacts/simulators.txt"
  exit 1
fi

IFS=$'\t' read -r simulator_id device_name simulator_runtime simulator_sdk <<<"$selection"
echo "Simulator: $device_name, iOS $simulator_runtime, selected Xcode SDK $simulator_sdk ($simulator_id)"
xcode_version="$(xcodebuild -version | tr '\n' ' ')"
echo "Xcode: $xcode_version"

defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false
xcrun simctl bootstatus "$simulator_id" -b
xcrun simctl status_bar "$simulator_id" override \
  --time "9:41" \
  --batteryState charged \
  --batteryLevel 100 \
  --wifiBars 3 \
  --cellularMode active \
  --cellularBars 4 || true

destination="platform=iOS Simulator,id=$simulator_id"
derived="$artifacts/derived"
test_status=0

# Preserve xcodebuild's exit status while still generating failure evidence.
set +e
xcodebuild build-for-testing \
  -project PourSTL.xcodeproj \
  -scheme PourSTLQA \
  -destination "$destination" \
  -derivedDataPath "$derived" \
  CODE_SIGNING_ALLOWED=NO \
  | tee "$artifacts/pourstl-xcodebuild.log"
test_status=${PIPESTATUS[0]}
set -e

app_path="$derived/Build/Products/Debug-iphonesimulator/PourSTL.app"
if [[ "$test_status" -eq 0 ]]; then
  bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Info.plist")"
  if [[ "$bundle_id" != "com.pourstl.app" ]]; then
    echo "Refusing to test an unexpected bundle id: $bundle_id"
    test_status=1
  else
    xcrun simctl install "$simulator_id" "$app_path"
    xcrun simctl privacy "$simulator_id" revoke camera com.pourstl.app || true
    set +e
    # Quality checks runs all 162 unit tests, including real StoreKit sessions.
    # Avoid repeating those nine slow integration cases before UI feedback;
    # all other unit tests and every UI test still run here. Release validation
    # requires both workflows to pass at the same commit.
    xcodebuild test-without-building \
      -project PourSTL.xcodeproj \
      -scheme PourSTLQA \
      -skip-testing:PourSTLTests/ProEntitlementStoreTests \
      -destination "$destination" \
      -derivedDataPath "$derived" \
      -resultBundlePath "$artifacts/PourSTLQA.xcresult" \
      -parallel-testing-enabled NO \
      CODE_SIGNING_ALLOWED=NO \
      | tee -a "$artifacts/pourstl-xcodebuild.log"
    test_status=${PIPESTATUS[0]}
    set -e
  fi
fi

if [[ -d "$artifacts/PourSTLQA.xcresult" ]]; then
  xcrun xcresulttool get test-results summary \
    --path "$artifacts/PourSTLQA.xcresult" \
    > "$artifacts/pourstl-test-summary.json" || test_status=1
fi

shot_src="$(find "$HOME/Library/Developer/CoreSimulator/Devices/$simulator_id" \
  -type d -name 'pourstl-screenshots-*' -newer "$artifacts/run-start" -print -quit || true)"
if [[ -n "$shot_src" ]]; then
  cp -R "$shot_src"/. "$artifacts/screenshots/"
fi

sha="$(git rev-parse HEAD)"

set +e
python3 scripts/qa_results.py \
  --log "$artifacts/pourstl-xcodebuild.log" \
  --observations "$artifacts/screenshots/observations.txt" \
  --screenshots "$artifacts/screenshots" \
  --output "$artifacts/qa-results.md" \
  --summary "$artifacts/pourstl-test-summary.json" \
  --sha "$sha" \
  --device "$device_name" \
  --runtime "$simulator_runtime" \
  --sdk "$simulator_sdk" \
  --xcode "$xcode_version"
results_status=$?
set -e

if [[ -n "${GITHUB_STEP_SUMMARY:-}" && -f "$artifacts/qa-results.md" ]]; then
  cat "$artifacts/qa-results.md" >> "$GITHUB_STEP_SUMMARY"
fi
echo "QA evidence: $artifacts"

if [[ "$test_status" -ne 0 ]]; then
  exit "$test_status"
fi
exit "$results_status"
