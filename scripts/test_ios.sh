#!/usr/bin/env bash
# Requires macOS with Xcode and at least one available iOS 17+ iPhone simulator.
set -euo pipefail
cd "$(dirname "$0")/.."
xcodebuild -version

simulator_id="$(python3 - <<'PY'
import json
import re
import subprocess

devices = json.loads(subprocess.check_output(
    ["xcrun", "simctl", "list", "devices", "available", "--json"], text=True
))["devices"]
candidates = []
for runtime, entries in devices.items():
    version = re.search(r"\.iOS-(\d+(?:-\d+)*)$", runtime)
    if not version:
        continue
    numbers = tuple(map(int, version.group(1).split("-")))
    if numbers[0] < 17:
        continue
    for device in entries:
        if device.get("isAvailable") and device["name"].startswith("iPhone"):
            candidates.append((numbers, device["name"], device["udid"]))
if not candidates:
    raise SystemExit("No available iOS 17+ iPhone simulator; install a simulator runtime in Xcode.")
print(max(candidates)[2])
PY
)"

results_directory="${RUNNER_TEMP:-$(mktemp -d)}"
# Result bundles must be new; do not delete an existing local run.
if [[ -e "$results_directory/PourTests.xcresult" ]]; then
  results_directory="$(mktemp -d "$results_directory/pour-tests.XXXXXX")"
fi
xcrun simctl bootstatus "$simulator_id" -b
xcodebuild test \
  -project Pour.xcodeproj \
  -scheme Pour \
  -destination "platform=iOS Simulator,id=$simulator_id" \
  -derivedDataPath "$results_directory/pour-derived-data" \
  -resultBundlePath "$results_directory/PourTests.xcresult" \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO \
  | tee "$results_directory/pour-xcodebuild.log"

# A successful process with no executed tests is not a passing test run.
xcrun xcresulttool get test-results summary \
  --path "$results_directory/PourTests.xcresult" \
  > "$results_directory/pour-test-summary.json"
python3 - "$results_directory/pour-test-summary.json" <<'PY'
import json
import sys

with open(sys.argv[1]) as stream:
    summary = json.load(stream)
assert summary["totalTestCount"] > 0, "XCTest did not discover any tests"
assert summary["passedTests"] > 0, "No XCTest tests passed"
assert summary["failedTests"] == 0, "XCTest failures reported"
print("XCTest:", summary["passedTests"], "passed,", summary["skippedTests"], "skipped")
PY
