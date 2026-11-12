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
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  printf 'results_directory=%s\n' "$results_directory" >> "$GITHUB_OUTPUT"
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

# Build the installable artifact in Release as a separate check of production
# compilation. Simulator apps cannot be installed on a physical iPhone.
xcodebuild build \
  -project Pour.xcodeproj \
  -scheme Pour \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$results_directory/pour-release-derived-data" \
  CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO 'ARCHS=arm64 x86_64' \
  | tee "$results_directory/pour-release-build.log"

app_path="$results_directory/pour-release-derived-data/Build/Products/Release-iphonesimulator/Pour.app"
artifact_directory="$results_directory/simulator-app"
mkdir -p "$artifact_directory"
ditto -c -k --sequesterRsrc --keepParent "$app_path" "$artifact_directory/Pour-Simulator.zip"
cp docs/PERSONAL_TESTING.md "$artifact_directory/README.md"
python3 - "$app_path" "$artifact_directory" "$results_directory/pour-test-summary.json" "$simulator_id" <<'PY'
import datetime
import hashlib
import json
import platform
import plistlib
import subprocess
import sys
from pathlib import Path

app, output, summary_path = map(Path, sys.argv[1:4])
with (app / "Info.plist").open("rb") as stream:
    info = plistlib.load(stream)
assert info.get("CFBundleSupportedPlatforms") == ["iPhoneSimulator"], "Unexpected native platform"
executable = app / info["CFBundleExecutable"]
architectures = subprocess.check_output(["xcrun", "lipo", "-archs", str(executable)], text=True).split()
assert set(architectures) == {"arm64", "x86_64"}, f"Incomplete simulator architectures: {architectures}"
summary = json.loads(summary_path.read_text())
git = lambda *args: subprocess.check_output(["git", *args], text=True).strip()
archive = output / "Pour-Simulator.zip"
manifest = {
    "schemaVersion": 1,
    "app": "Pour",
    "sourceCommit": git("rev-parse", "HEAD"),
    "sourceTree": git("rev-parse", "HEAD^{tree}"),
    "workingTreeDirty": bool(git("status", "--porcelain", "--untracked-files=no")),
    "builtAtUTC": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "configuration": "Release",
    "nativePlatform": "iPhoneSimulator",
    "architectures": architectures,
    "runnerArchitecture": platform.machine(),
    "bundleIdentifier": info["CFBundleIdentifier"],
    "version": info["CFBundleShortVersionString"],
    "build": info["CFBundleVersion"],
    "minimumOSVersion": info["MinimumOSVersion"],
    "sdk": info.get("DTSDKName"),
    "xcode": subprocess.check_output(["xcodebuild", "-version"], text=True).strip(),
    "codeSigningAllowed": False,
    "physicalIPhoneCompatible": False,
    "testFlightBuild": False,
    "unitTestSimulatorUDID": sys.argv[4],
    "unitTests": {key: summary[key] for key in ("totalTestCount", "passedTests", "failedTests", "skippedTests")},
    "archiveSHA256": hashlib.sha256(archive.read_bytes()).hexdigest(),
}
(output / "build-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(json.dumps(manifest, indent=2))
PY
echo "Simulator app: $artifact_directory"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  printf 'artifact_directory=%s\n' "$artifact_directory" >> "$GITHUB_OUTPUT"
fi
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    printf '### Pour simulator build\n\n'
    printf 'Commit: `%s`\n\n' "$(git rev-parse HEAD)"
    printf 'Download **Pour-Simulator** from this run’s artifacts. It includes a Release app for Apple Silicon and Intel Mac simulators, a build manifest, and installation instructions.\n\n'
    printf 'This unsigned iOS Simulator build is not a physical-iPhone or TestFlight installation. Full UI evidence is in the separate **Simulator QA pass** workflow for the same commit.\n'
  } >> "$GITHUB_STEP_SUMMARY"
fi
