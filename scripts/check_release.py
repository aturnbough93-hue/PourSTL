#!/usr/bin/env python3
"""Dependency-free checks for the release metadata and tracked source."""

import argparse
import json
from pathlib import Path
import plistlib
import re
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]
PROJECT = "project.yml"
PBXPROJ = "PourSTL.xcodeproj/project.pbxproj"
INFO = "PourSTL/Info.plist"
ASSETS = ROOT / "PourSTL/Assets.xcassets"
BUNDLE_ID = "bar.pourstl.app"
INFO_SETTINGS = {
    "CFBundleIdentifier": "PRODUCT_BUNDLE_IDENTIFIER",
    "CFBundleShortVersionString": "MARKETING_VERSION",
    "CFBundleVersion": "CURRENT_PROJECT_VERSION",
}
SECRET_PATTERNS = {
    "AWS access key ID": rb"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b",
    "GitHub personal access token": rb"\b(?:ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{82})\b",
    "Private key": rb"-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY-----",
    "Slack token": rb"\bxox[bp]-[A-Za-z0-9-]{10,}[A-Za-z0-9]\b",
    "Cloudflare API token": rb"""(?i)\b(?:CLOUDFLARE|CF)_API_TOKEN["']?\s*[:=]\s*["']?[A-Za-z0-9_-]{40}(?![A-Za-z0-9_-])""",
    "sk-style API key": rb"\bsk-[A-Za-z0-9_-]{20,}[A-Za-z0-9]\b",
}


def yaml_fields(text):
    """Read the immediate keys of an indented block in our XcodeGen spec."""
    text = text.replace("\r\n", "\n").removesuffix("\r")
    lines = [line for line in text.splitlines() if line.strip() and not line.lstrip().startswith("#")]
    indent = min(len(line) - len(line.lstrip()) for line in lines)
    entries = list(re.finditer(rf"(?m)^ {{{indent}}}([\w.-]+):[ \t]*(.*)$", text))
    fields = {}
    for index, entry in enumerate(entries):
        key, value = entry.groups()
        end = entries[index + 1].start() if index + 1 < len(entries) else len(text)
        quoted = re.match(r"""^("(?:[^"\\]|\\.)*"|'(?:[^']|'')*')(?=[ \t]*(?:$|[ \t]#))""", value)
        if quoted:
            fields[key] = quoted.group(1)[1:-1]
        else:
            value = re.split(r"(?:^|[ \t]+)#", value, maxsplit=1)[0].strip()
            fields[key] = value or text[entry.end():end].strip("\n")
    return fields


def app_spec(text):
    return yaml_fields(yaml_fields(yaml_fields(text)["targets"])["PourSTL"])


def pbx_objects(text):
    """Index Xcode's OpenStep object table; target relationships use IDs, not comments."""
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    pattern = r"^\t\t(\w+)\s*=\s*\{\n(.*?)^\t\t\};|^\t\t(\w+)\s*=\s*\{([^\n]*)\};"
    return {
        multi_id or single_id: multi_body or single_body
        for multi_id, multi_body, single_id, single_body in re.findall(pattern, text, re.MULTILINE | re.DOTALL)
    }


def pbx_value(text, key):
    match = re.search(rf"\b{re.escape(key)}\s*=\s*([^;]+);", text)
    if not match:
        raise ValueError(f"Missing {key} in {PBXPROJ}")
    return match.group(1).strip().strip('"')


def pbx_ids(text, key):
    return pbx_value(text, key).strip("()").replace(",", " ").split()


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)


class ReleaseChecks(unittest.TestCase):
    base_ref = None

    @classmethod
    def setUpClass(cls):
        cls.spec = app_spec((ROOT / PROJECT).read_text())
        cls.settings = yaml_fields(yaml_fields(cls.spec["settings"])["base"])
        cls.properties = yaml_fields(yaml_fields(cls.spec["info"])["properties"])
        cls.info = plistlib.loads((ROOT / INFO).read_bytes())
        cls.objects = pbx_objects((ROOT / PBXPROJ).read_text())
        cls.target, = (
            obj for obj in cls.objects.values()
            if re.search(r"\bisa = PBXNativeTarget;", obj) and pbx_value(obj, "name") == "PourSTL"
        )
        configs = cls.objects[pbx_value(cls.target, "buildConfigurationList")]
        cls.configs = [cls.objects[ref] for ref in pbx_ids(configs, "buildConfigurations")]

    def assert_app_setting(self, key, expected):
        self.assertEqual(self.settings.get(key), expected, f"{PROJECT}: {key}")
        for config in self.configs:
            with self.subTest(configuration=pbx_value(config, "name"), setting=key):
                self.assertEqual(pbx_value(config, key), expected, PBXPROJ)

    def test_bundle_id_and_versions(self):
        self.assertTrue(self.configs, "The app target has no build configurations")
        self.assert_app_setting("PRODUCT_BUNDLE_IDENTIFIER", BUNDLE_ID)
        for setting, pattern in (
            ("MARKETING_VERSION", r"[0-9]+\.[0-9]+\.[0-9]+"),
            ("CURRENT_PROJECT_VERSION", r"[1-9][0-9]*"),
        ):
            value = self.settings.get(setting, "")
            self.assertRegex(value, rf"^{pattern}$", f"{PROJECT}: invalid {setting}")
            self.assert_app_setting(setting, value)
        self.assertEqual(yaml_fields(self.spec["info"]).get("path"), INFO)
        for config in self.configs:
            self.assertEqual(pbx_value(config, "INFOPLIST_FILE"), INFO)
        for plist_key, setting in INFO_SETTINGS.items():
            with self.subTest(key=plist_key):
                expected = f"$({setting})"
                self.assertEqual(self.properties.get(plist_key), expected, PROJECT)
                self.assertEqual(self.info.get(plist_key), expected, INFO)

    def test_app_icon_and_launch_screen(self):
        self.assert_app_setting("ASSETCATALOG_COMPILER_APPICON_NAME", "AppIcon")
        self.assertIn("Assets.xcassets", self.app_resources())
        icons = ASSETS / "AppIcon.appiconset"
        images = json.loads((icons / "Contents.json").read_text())["images"]
        filenames = [image["filename"] for image in images if "filename" in image]
        self.assertTrue(filenames, "AppIcon has no images")
        for filename in filenames:
            self.assertTrue((icons / filename).is_file(), f"AppIcon image missing: {filename}")
        launch = self.info.get("UILaunchScreen")
        self.assertIsInstance(launch, dict, "Info.plist is missing UILaunchScreen")
        color = launch.get("UIColorName")
        self.assertTrue(color, "UILaunchScreen has no color asset")
        self.assertEqual(yaml_fields(self.properties["UILaunchScreen"]).get("UIColorName"), color)
        self.assertTrue((ASSETS / f"{color}.colorset" / "Contents.json").is_file())

    def app_resources(self):
        resources = set()
        for ref in pbx_ids(self.target, "buildPhases"):
            phase = self.objects[ref]
            if pbx_value(phase, "isa") != "PBXResourcesBuildPhase":
                continue
            for build_ref in pbx_ids(phase, "files"):
                file_ref = pbx_value(self.objects[build_ref], "fileRef")
                resources.add(pbx_value(self.objects[file_ref], "path"))
        return resources

    def test_privacy_manifest(self):
        manifest = plistlib.loads((ROOT / "PourSTL/PrivacyInfo.xcprivacy").read_bytes())
        self.assertIs(manifest.get("NSPrivacyTracking"), False)
        declarations = manifest.get("NSPrivacyAccessedAPITypes")
        self.assertIsInstance(declarations, list)
        self.assertTrue(declarations, "Privacy manifest has no required-reason API declarations")
        for declaration in declarations:
            self.assertTrue(declaration.get("NSPrivacyAccessedAPIType"))
            reasons = declaration.get("NSPrivacyAccessedAPITypeReasons")
            self.assertIsInstance(reasons, list)
            self.assertTrue(reasons and all(isinstance(reason, str) and reason for reason in reasons))
        if any(
            re.search(r"\bUserDefaults\b|@AppStorage\b", source.read_text())
            for source in (ROOT / "PourSTL").rglob("*.swift")
        ):
            self.assertIn(
                "NSPrivacyAccessedAPICategoryUserDefaults",
                {declaration["NSPrivacyAccessedAPIType"] for declaration in declarations},
                "Swift uses UserDefaults or @AppStorage; declare the UserDefaults API category and its reasons",
            )
        self.assertIn("PrivacyInfo.xcprivacy", self.app_resources())

    def test_settings_links_have_website_pages(self):
        settings = (ROOT / "PourSTL/Features/Settings/SettingsView.swift").read_text()
        for page in ("support", "privacy"):
            with self.subTest(page=page):
                self.assertIn(f'URL(string: "https://pourstl.com/{page}")', settings)
                self.assertTrue((ROOT / "website" / f"{page}.html").is_file())

    def test_no_obvious_secrets_in_tracked_files(self):
        hits = []
        for name in set(git("ls-files", "-z").decode(errors="surrogateescape").split("\0")) - {""}:
            path = ROOT / name
            if path.is_symlink() or not path.is_file():
                continue
            data = path.read_bytes()
            for label, pattern in SECRET_PATTERNS.items():
                if re.search(pattern, data):
                    hits.append(f"{name}: {label}")
        self.assertFalse(hits, "Potential secrets (values omitted):\n" + "\n".join(sorted(hits)))

    def test_release_build_number_increased(self):
        if self.base_ref is None:
            self.skipTest("No release baseline requested")
        commit = git("rev-parse", "--verify", "--end-of-options", f"{self.base_ref}^{{commit}}").decode().strip()
        base = git("show", f"{commit}:{PROJECT}").decode()
        previous = yaml_fields(yaml_fields(app_spec(base)["settings"])["base"])["CURRENT_PROJECT_VERSION"]
        current = self.settings["CURRENT_PROJECT_VERSION"]
        self.assertGreater(int(current), int(previous), f"Build number must increase from {previous} at {self.base_ref}")


class YamlFieldTests(unittest.TestCase):
    def test_inline_comments_after_scalars(self):
        fields = yaml_fields(
            'CURRENT_PROJECT_VERSION: "5" # TestFlight\n'
            "MARKETING_VERSION: 1.0.0 # Release\n"
            'DoubleQuoted: "value # retained" # comment\n'
            "SingleQuoted: 'value # retained' # comment\n"
            "URL: https://example.test/path#fragment # comment\n"
        )
        self.assertEqual(fields, {
            "CURRENT_PROJECT_VERSION": "5",
            "MARKETING_VERSION": "1.0.0",
            "DoubleQuoted": "value # retained",
            "SingleQuoted": "value # retained",
            "URL": "https://example.test/path#fragment",
        })

    def test_inline_comment_before_nested_block(self):
        fields = yaml_fields("settings: # App settings\n  CURRENT_PROJECT_VERSION: 5\n")
        self.assertEqual(yaml_fields(fields["settings"]), {"CURRENT_PROJECT_VERSION": "5"})

    def test_crlf_quoted_build_number(self):
        fields = yaml_fields('settings:\r\n  CURRENT_PROJECT_VERSION: "5"\r\n')
        self.assertEqual(yaml_fields(fields["settings"]), {"CURRENT_PROJECT_VERSION": "5"})


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, add_help=False)
    parser.add_argument("--version-bumped-since", metavar="REF")
    args, rest = parser.parse_known_args()
    ReleaseChecks.base_ref = args.version_bumped_since
    unittest.main(argv=[__file__, *rest])
