#!/usr/bin/env bash
# GitHub-hosted iPhone simulator QA. No paid device farms, secrets, or third-party services.
set -euo pipefail
cd "$(dirname "$0")/.."

artifacts="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/pour-qa.XXXXXX")"
mkdir -p "$artifacts/screenshots"
touch "$artifacts/run-start"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  printf 'artifacts_directory=%s\n' "$artifacts" >> "$GITHUB_OUTPUT"
fi

select_device() {
  python3 - <<'PY'
import json
import re
import subprocess
import sys

devices = json.loads(subprocess.check_output(
    ["xcrun", "simctl", "list", "devices", "available", "--json"], text=True
))["devices"]
preferred = ["iPhone 17 Pro Max", "iPhone 16 Pro Max"]
found = {name: [] for name in preferred}
for runtime, entries in devices.items():
    version = re.search(r"\.iOS-(\d+(?:-\d+)*)$", runtime)
    if not version:
        continue
    numbers = tuple(int(part) for part in version.group(1).split("-"))
    if numbers[0] < 17:
        continue
    for device in entries:
        if device.get("isAvailable") and device["name"] in found:
            found[device["name"]].append((numbers, device["udid"], device["name"]))
for name in preferred:
    if found[name]:
        _numbers, udid, chosen = max(found[name])
        print(f"{udid}\t{chosen}")
        sys.exit(0)
print("No iPhone 17 Pro Max or iPhone 16 Pro Max simulator.", file=sys.stderr)
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

IFS=$'\t' read -r simulator_id device_name <<<"$selection"
echo "Simulator: $device_name ($simulator_id)"
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
  -project Pour.xcodeproj \
  -scheme PourQA \
  -destination "$destination" \
  -derivedDataPath "$derived" \
  CODE_SIGNING_ALLOWED=NO \
  | tee "$artifacts/pour-xcodebuild.log"
test_status=${PIPESTATUS[0]}
set -e

app_path="$derived/Build/Products/Debug-iphonesimulator/Pour.app"
if [[ "$test_status" -eq 0 ]]; then
  bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Info.plist")"
  if [[ "$bundle_id" != "com.devin.pour" ]]; then
    echo "Refusing to test an unexpected bundle id: $bundle_id"
    test_status=1
  else
    xcrun simctl install "$simulator_id" "$app_path"
    xcrun simctl privacy "$simulator_id" revoke camera com.devin.pour || true
    set +e
    xcodebuild test-without-building \
      -project Pour.xcodeproj \
      -scheme PourQA \
      -destination "$destination" \
      -derivedDataPath "$derived" \
      -resultBundlePath "$artifacts/PourQA.xcresult" \
      -parallel-testing-enabled NO \
      CODE_SIGNING_ALLOWED=NO \
      | tee -a "$artifacts/pour-xcodebuild.log"
    test_status=${PIPESTATUS[0]}
    set -e
  fi
fi

if [[ -d "$artifacts/PourQA.xcresult" ]]; then
  xcrun xcresulttool get test-results summary \
    --path "$artifacts/PourQA.xcresult" \
    > "$artifacts/pour-test-summary.json" || test_status=1
fi

shot_src="$(find "$HOME/Library/Developer/CoreSimulator/Devices/$simulator_id" \
  -type d -name 'pour-screenshots-*' -newer "$artifacts/run-start" -print -quit || true)"
if [[ -n "$shot_src" ]]; then
  cp -R "$shot_src"/. "$artifacts/screenshots/"
fi

sha="$(git rev-parse HEAD)"

set +e
python3 scripts/qa_results.py \
  --log "$artifacts/pour-xcodebuild.log" \
  --observations "$artifacts/screenshots/observations.txt" \
  --screenshots "$artifacts/screenshots" \
  --output "$artifacts/qa-results.md" \
  --summary "$artifacts/pour-test-summary.json" \
  --sha "$sha" \
  --device "$device_name" \
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
