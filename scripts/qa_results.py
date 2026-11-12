#!/usr/bin/env python3
"""Turn the simulator QA log into a checklist. Reads the xcodebuild log; it does not invent passes."""

import argparse
import json
import re
import struct
import sys
from pathlib import Path

EXPECTED_SHOTS = [
    "01-home.png",
    "02-what-can-i-make.png",
    "03-recipe-detail.png",
    "04-my-bar.png",
    "05-barcode-confirm.png",
    "06-shopping-list.png",
    "07-timer.png",
    "08-settings.png",
]
EXPECTED_SIZE = (1320, 2868)

CASE = re.compile(
    r"Test Case '-\[(?P<cls>[^\]]+?) (?P<name>test[A-Za-z0-9_]+)\]' (?P<result>passed|failed|skipped)"
)


def png_size(path: Path):
    # Read only the fixed IHDR header, including for malformed/truncated files.
    with path.open("rb") as stream:
        data = stream.read(24)
    if len(data) != 24 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        return None
    if struct.unpack(">I", data[8:12])[0] != 13:
        return None
    return struct.unpack(">II", data[16:24])


def load_results(log_text: str):
    found = {}
    for match in CASE.finditer(log_text):
        name, result = match.group("name"), match.group("result")
        # A later retry must not hide a failure in this run.
        if found.get(name) != "failed":
            found[name] = result
    return found


def outcome(found, names):
    if not names:
        return "missing"
    states = [found.get(name) for name in names]
    if any(state is None for state in states):
        return "missing"
    if any(state == "failed" for state in states):
        return "fail"
    if all(state == "passed" for state in states):
        return "pass"
    return "fail"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--log", required=True)
    parser.add_argument("--observations", required=True)
    parser.add_argument("--screenshots", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--sha", required=True)
    parser.add_argument("--device", required=True)
    parser.add_argument("--xcode", required=True)
    parser.add_argument("--summary", required=True)
    args = parser.parse_args()

    log_path = Path(args.log)
    log_text = log_path.read_text(errors="replace") if log_path.exists() else ""
    found = load_results(log_text)
    observations = {}
    obs_path = Path(args.observations)
    if obs_path.exists():
        for line in obs_path.read_text(errors="replace").splitlines():
            if "=" in line:
                key, value = line.split("=", 1)
                observations[key.strip()] = value.strip()

    shots_dir = Path(args.screenshots)
    shot_lines = []
    shot_ok = True
    for name in EXPECTED_SHOTS:
        path = shots_dir / name
        if not path.exists():
            shot_lines.append(f"- `{name}`: missing")
            shot_ok = False
            continue
        size = png_size(path)
        if size == EXPECTED_SIZE:
            shot_lines.append(f"- `{name}`: {size[0]}x{size[1]}")
        else:
            actual = f"{size[0]}x{size[1]}" if size else "unreadable"
            shot_lines.append(f"- `{name}`: {actual}, expected 1320x2868")
            shot_ok = False

    fallback = observations.get("camera-fallback", "not recorded")

    rows = [
        ("1a", "Camera usage text matches the shipped prompt copy", outcome(found, ["testCameraUsageDescriptionMatchesThePromptCopy"]), "Unit test reads NSCameraUsageDescription from the app bundle."),
        ("1b", "System camera permission prompt shows that text", "needs device", "The simulator does not present the iOS permission alert. The string itself is 1a."),
        ("2", "Denied camera shows Open Settings, digit entry, and add by name", outcome(found, ["testDeniedCameraShowsSettingsFallback"]), f"Shown by passing the denied state into BarcodeCameraPolicy. After `simctl privacy revoke camera`, the unhooked scanner reported `{fallback}`."),
        ("3", "Restricted camera shows the same fallback and does not loop", outcome(found, ["testRestrictedCameraStaysOnTheFallback"]), "Simulated through CameraAuthorizationState.restricted. A real MDM restriction still needs a device."),
        ("4", "Granting camera in Settings and returning restarts the preview", "needs device", "Requires the system Settings app and a camera."),
        ("5", "Known UPC shows the confirm sheet and nothing is saved before confirm", outcome(found, ["testKnownUPCShowsConfirmSheetAndDoesNotSaveUntilConfirm"]), "Manual entry of Tanqueray 088110110307. Cancel leaves My Bar unchanged."),
        ("6", "Unknown code opens name entry, and In stock off saves out of stock", outcome(found, ["testUnknownCodeSavesOutOfStockWhenToggleIsOff"]), "Manual entry of 012345678905 saved as Fernet Branca."),
        ("7", "QR plus UPC in one frame picks the UPC", "pass (unit only)" if outcome(found, ["testProductBarcodeBeatsALeadingMarketingQR"]) == "pass" else outcome(found, ["testProductBarcodeBeatsALeadingMarketingQR"]), "Existing unit test testProductBarcodeBeatsALeadingMarketingQR. The simulator has no camera frame."),
        ("8", "Cancel, Not now, or Done does not instantly reopen the same code", "pass (unit); needs device (UI)" if outcome(found, ["testDismissedSheetDoesNotReopenWhileTheCodeStaysInFrame"]) == "pass" else "fail", "Latch covered by testDismissedSheetDoesNotReopenWhileTheCodeStaysInFrame. Reopening from a live viewfinder needs a device."),
        ("9", "Scanning a code already on the bar offers that bottle and does not add a row", outcome(found, ["testRescanShowsAlreadyInBarWithoutADuplicate"]), "Second manual entry of Tanqueray shows Already in your bar. One Edit Tanqueray row."),
        ("10", "Two bottles with the same name: restock updates only the scanned row", outcome(found, ["testSameNameRestockUpdatesOnlyTheScannedRow"]), "The barcoded House Amaro is marked in stock. The other House Amaro stays low stock. Still two rows."),
        ("11", "Ambiguous 8-digit entry shows the EAN-8 / UPC-E picker with the typed digits", outcome(found, ["testAmbiguousEightDigitsShowsThePrintedCode"]), "01000009. Both buttons show those digits."),
        ("12a", "Torch", "needs device", "The simulator has no torch."),
        ("12b", "Rotation while the scanner is up", outcome(found, ["testScannerSurvivesRotation"]), "Portrait lock stays usable in landscape and back."),
        ("12c", "Background and foreground during a scan", outcome(found, ["testScannerSurvivesBackgrounding", "testStoppingTheSessionClearsASwallowedInterruption"]), "UI leaves the scanner and returns to manual entry. A unit test covers the interruption latch. A running preview still needs a camera."),
        ("12d", "Airplane mode", "needs device", "Search is local, but the radios were not switched off."),
        ("13", "VoiceOver labels on the scan button, Open Settings, picker, and toggles", outcome(found, ["testVoiceOverLabelsOnScannerControls"]), "Scan barcode to add ingredient, Open Settings, Use EAN-8 / Use UPC-E, In stock and Low stock."),
        ("S1", "Search the local library", outcome(found, ["testSearchFiltersTheLocalLibrary"]), "Negroni stays. Margarita is filtered out. No network call in this path."),
        ("S2", "What can I make", outcome(found, ["testWhatCanIMakeListsAStockedDrink"]), "Demo bar from -demoInventory. Header reports 7 drinks, including Negroni and Gimlet."),
        ("S3", "Scaling and oz/ml", outcome(found, ["testScalingUpdatesTheMeasure"]), "Negroni 1 oz Gin becomes 2 oz, then 59 ml."),
        ("S4", "Shopping list add and delete", outcome(found, ["testShoppingListAddAndDelete"]), "Orange peel is added, then swiped away."),
        ("S5", "Custom recipe save", outcome(found, ["testCustomRecipeSaves"]), "Shift Special with Bourbon appears in search."),
        ("S6", "pour:// deep link", outcome(found, ["testRecipeDeepLinkOpensTheDrink", "testShoppingDeepLinkSelectsTheTab"]), "pour://recipe?name=Negroni and pour://tab/shopping."),
        ("S7", "Settings persist", outcome(found, ["testSettingsUnitsPersistAcrossLaunch"]), "Preferred units stay on ml after relaunch."),
        ("S8", "Current testing screenshots", "pass" if shot_ok and outcome(found, ["testCaptureTestingScreenshots"]) == "pass" else "fail", "Eight portrait PNGs captured by this run. The barcode image follows manual entry. These are testing evidence, not App Store approval."),
        ("S9", "Classic variation can be cancelled", outcome(found, ["testClassicVariationCanBeCancelledWithoutChangingTheOriginal"]), "Pre-filled Negroni variation editor is dismissed; the original remains read-only."),
        ("S10", "Offline Bar Assistant", outcome(found, ["testAssistantAnswersFromTheDemoBar"]), "A supported starter question returns Negroni from the demo inventory. No AI service is connected."),
        ("S11", "Pro sheet navigation keeps free recipes available", outcome(found, ["testProSheetCanBeDismissedWithoutPurchasing"]), "Subscription sheet opens, exposes Restore purchases, and dismisses. No purchase or restore action is invoked; billing still needs StoreKit and sandbox validation."),
    ]

    failures = []
    for line in log_text.splitlines():
        if " error: " in line or line.strip().startswith("error:") or "XCTAssert" in line and "failed" in line:
            failures.append(line.strip())
    failures = failures[:40]

    summary = ""
    summary_ok = False
    summary_error = "No valid XCTest summary was produced."
    summary_path = Path(args.summary)
    if summary_path.is_file():
        summary = summary_path.read_text(errors="replace").strip()
        try:
            counts = json.loads(summary)
            summary_ok = (
                counts["totalTestCount"] > 0
                and counts["passedTests"] > 0
                and counts["failedTests"] == 0
                and counts.get("result") != "Failed"
            )
            summary_error = "XCTest must execute tests, pass at least one, and report zero failures."
        except (ValueError, KeyError, TypeError):
            summary_error = "The XCTest summary is malformed or missing test counts."

    lines = [
        "# Simulator QA pass",
        "",
        f"- Tested SHA: `{args.sha}`",
        f"- Device: {args.device}",
        f"- Xcode: {args.xcode}",
        "- Bundle ID: `com.devin.pour`",
        f"- XCTest summary: {'pass' if summary_ok else 'fail'}",
        "",
        "This report covers the simulator at the exact commit above. Physical camera, torch, real device lifecycle, and signed distribution still need iPhone testing before launch.",
        "",
        "## Checklist",
        "",
        "| Item | Result | Evidence |",
        "| --- | --- | --- |",
    ]
    for item, title, result, evidence in rows:
        lines.append(f"| {item}. {title} | {result} | {evidence} |")

    lines.extend(["", "## Screenshots", ""])
    lines.extend(shot_lines or ["- No screenshot directory was produced."])
    if summary:
        lines.extend(["", "## XCTest summary", "", "```", summary, "```"])
    if not summary_ok:
        lines.extend(["", f"XCTest evidence failed: {summary_error}"])
    if failures:
        lines.extend(["", "## Failure excerpts", ""])
        lines.extend(f"- `{line}`" for line in failures)
    lines.append("")

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines))
    print(output.read_text())
    automated_failed = any(result in {"fail", "missing"} for _, _, result, _ in rows)
    any_test_failed = any(result == "failed" for result in found.values())
    if automated_failed or any_test_failed or not shot_ok or not summary_ok:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
