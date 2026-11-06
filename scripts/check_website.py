#!/usr/bin/env python3
"""Dependency-free static regression checks. Run: python3 scripts/check_website.py.

These checks complement rendered browser QA; they do not prove WCAG conformance
or that the hosting provider has applied the response-header configuration.
"""

from html.parser import HTMLParser
from pathlib import Path
import re
import unittest
from urllib.parse import unquote, urlsplit
import xml.etree.ElementTree as ET


SITE = Path(__file__).resolve().parents[1] / "website"


class Page(HTMLParser):
    def __init__(self, source):
        super().__init__(convert_charrefs=True)
        self.tags = []
        self.ids = []
        self.links = []
        self.scripts = []
        self.inline_script = []
        self.in_script = False
        self.feed(source)

    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        self.tags.append((tag, values))
        if "id" in values:
            self.ids.append(values["id"])
        for name in ("href", "src"):
            if values.get(name):
                self.links.append(values[name])
        if tag == "script":
            self.scripts.append(values)
            self.in_script = True

    def handle_endtag(self, tag):
        if tag == "script":
            self.in_script = False

    def handle_data(self, text):
        if self.in_script and text.strip():
            self.inline_script.append(text)


def local_target(page_path, reference):
    """Resolve root-relative and relative site links, including directory URLs."""
    parsed = urlsplit(reference)
    if parsed.scheme or parsed.netloc:
        return None
    path = unquote(parsed.path)
    target = (SITE / path.lstrip("/") if path.startswith("/")
              else page_path.parent / path if path else page_path)
    if target.is_dir():
        target /= "index.html"
    target = target.resolve()
    if not target.is_relative_to(SITE.resolve()):
        raise ValueError(f"Reference escapes the published site: {reference}")
    return target, unquote(parsed.fragment)


class WebsiteChecks(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sources = {path: path.read_text() for path in SITE.rglob("*.html")}
        cls.pages = {path: Page(source) for path, source in cls.sources.items()}

    def test_local_assets_links_and_fragments_exist(self):
        for path, page in self.pages.items():
            for reference in page.links:
                with self.subTest(page=path.name, reference=reference):
                    target = local_target(path, reference)
                    if target is None:
                        continue
                    target_path, fragment = target
                    self.assertTrue(target_path.is_file(), f"Missing {target_path}")
                    self.assertGreater(target_path.stat().st_size, 0)
                    if fragment:
                        self.assertIn(target_path, self.pages)
                        self.assertIn(fragment, self.pages[target_path].ids)
        for path, source in self.sources.items():
            for reference in re.findall(r"url\(\s*['\"]?([^)'\"\s]+)", source):
                target = local_target(path, reference)
                if target is not None:
                    self.assertTrue(target[0].is_file(), f"Missing CSS asset {reference}")

    def test_document_landmarks_and_image_alternatives(self):
        self.assertIn(SITE / "index.html", self.pages)
        self.assertIn(SITE / "privacy.html", self.pages)
        self.assertIn(SITE / "support.html", self.pages)
        self.assertIn(SITE / "404.html", self.pages)
        for path, page in self.pages.items():
            with self.subTest(page=path.name):
                self.assertEqual(len(page.ids), len(set(page.ids)), "Duplicate IDs")
                for tag in ("main", "h1", "title"):
                    self.assertEqual(sum(name == tag for name, _ in page.tags), 1, tag)
                self.assertTrue(any(tag == "html" and attrs.get("lang")
                                    for tag, attrs in page.tags))
                for tag, attrs in page.tags:
                    if tag == "img":
                        self.assertIn("alt", attrs)

    def test_scripts_are_compatible_with_self_only_csp(self):
        for path, page in self.pages.items():
            with self.subTest(page=path.name):
                self.assertFalse(page.inline_script, "Inline script blocked by script-src 'self'")
                for script in page.scripts:
                    self.assertTrue(script.get("src"), "Script must be external")
                    self.assertIsNotNone(local_target(path, script["src"]),
                                         "Remote script not permitted")
                for _, attrs in page.tags:
                    self.assertFalse(any(name.startswith("on") for name in attrs),
                                     "Inline event handlers are blocked by CSP")
                for tag, attrs in page.tags:
                    resource = (attrs.get("src") if tag in ("img", "script") else
                                attrs.get("href") if tag == "link" and
                                attrs.get("rel") == "stylesheet" else None)
                    if resource:
                        self.assertIsNotNone(local_target(path, resource),
                                             f"Remote {tag} resource blocked by CSP")
                for reference in page.links:
                    self.assertNotEqual(urlsplit(reference).scheme.lower(), "javascript")
        self.assertTrue(self.pages[SITE / "index.html"].scripts,
                        "Homepage navigation script missing")

    def test_security_headers_are_configured_for_all_pages(self):
        lines = (SITE / "_headers").read_text().splitlines()
        self.assertEqual(lines[0], "/*")
        headers = dict(line.strip().split(":", 1) for line in lines[1:] if line.strip())
        directives = {}
        for directive in headers["Content-Security-Policy"].split(";"):
            tokens = directive.split()
            if tokens:
                directives[tokens[0]] = tokens[1:]
        for name, value in {"script-src": ["'self'"], "connect-src": ["'none'"],
                            "frame-ancestors": ["'none'"], "object-src": ["'none'"],
                            "base-uri": ["'none'"], "form-action": ["'none'"]}.items():
            self.assertEqual(directives.get(name), value, name)
        self.assertEqual(headers["X-Content-Type-Options"].strip(), "nosniff")
        self.assertEqual(headers["X-Frame-Options"].strip(), "DENY")

    def test_privacy_support_and_sitemap_remain_reachable(self):
        homepage = self.pages[SITE / "index.html"]
        for name in ("privacy.html", "support.html"):
            self.assertTrue(any(local_target(SITE / "index.html", link) ==
                                (SITE / name, "") for link in homepage.links), name)
        sitemap = ET.parse(SITE / "sitemap.xml")
        locations = sitemap.findall(".//{http://www.sitemaps.org/schemas/sitemap/0.9}loc")
        self.assertGreaterEqual(len(locations), 2)
        paths = set()
        for location in locations:
            parsed = urlsplit(location.text)
            self.assertEqual(parsed.scheme, "https")
            paths.add(parsed.path)
            target = local_target(SITE / "index.html", parsed.path)
            self.assertTrue(target[0].is_file(), parsed.path)
        self.assertIn("/privacy.html", paths)
        self.assertIn("/support.html", paths)

    def test_subpages_share_the_existing_social_image(self):
        image = "https://barpour.pages.dev/assets/og-image.jpg"
        for name in ("index.html", "privacy.html", "try.html", "support.html"):
            source = self.sources[SITE / name]
            with self.subTest(page=name):
                self.assertIn(f'property="og:image" content="{image}"', source)
                self.assertIn(f'property="og:title"', source)
                self.assertIn(f'property="og:url" content="https://barpour.pages.dev/', source)
                self.assertIn('name="twitter:card" content="summary_large_image"', source)
                self.assertIn(f'name="twitter:image" content="{image}"', source)
        self.assertTrue((SITE / "assets" / "og-image.jpg").is_file())

    def test_support_points_at_github_issues_without_an_email(self):
        source = self.sources[SITE / "support.html"]
        self.assertIn("https://github.com/aturnbough93-hue/pour/issues", source)
        lowered = "\n".join(self.sources.values()).lower()
        self.assertNotIn("support@", lowered)
        self.assertNotIn("@example.com", lowered)

    def test_parked_homepage_does_not_offer_pro_or_a_competing_status_button(self):
        homepage = self.sources[SITE / "index.html"]
        self.assertNotIn('href="#pro"', homepage)
        self.assertNotIn('id="pro"', homepage)
        self.assertNotIn("hero-photo", homepage)
        self.assertNotIn(">App status<", homepage)
        self.assertGreaterEqual(homepage.count("iPhone app status"), 2)

    def test_empty_overlay_tap_closes_mobile_menu_without_falling_through(self):
        """AND-6: iPhone Safari often does not click a non-interactive overlay."""
        script = (SITE / "site.js").read_text()
        homepage = self.sources[SITE / "index.html"]
        menu_rule = re.search(r"\.nav-menu \{([^}]*)\}", homepage)
        self.assertIsNotNone(menu_rule)
        self.assertIn("cursor: pointer", menu_rule.group(1))
        self.assertIn("touch-action: manipulation", menu_rule.group(1))
        dismiss = re.search(r"function dismissEmptyOverlay\([\s\S]*?\n\}", script)
        self.assertIsNotNone(dismiss)
        self.assertIn("pointerType === 'mouse'", dismiss.group(0))
        self.assertIn("setMenuOpen(false, true)", dismiss.group(0))
        self.assertRegex(script, r"addEventListener\(\s*'pointerup'")
        self.assertRegex(script, r"addEventListener\(\s*'touchend'")
        sink = re.search(r"function swallowFollowingClick\(\) \{[\s\S]*?\n\}", script)
        self.assertIsNotNone(sink)
        self.assertIn("preventDefault", sink.group(0))
        self.assertIn("stopPropagation", sink.group(0))
        self.assertIn("detail === 0", sink.group(0))
        # Menu links keep the click path that moves focus to the destination.
        self.assertIn("closest('#nav-menu a')", script)

    def test_public_files_do_not_point_at_netlify(self):
        root = SITE.parent
        self.assertFalse((root / "netlify.toml").exists())
        self.assertTrue((SITE / "_headers").is_file())
        suffixes = {".html", ".txt", ".xml", ".md", ".py", ".yml", ".yaml", ".toml", ".js", ".cjs", ".json"}
        checked = 0
        for path in root.rglob("*"):
            if (not path.is_file() or path.resolve() == Path(__file__).resolve()
                    or any(part in {".git", "dist", "__pycache__"} for part in path.parts)
                    or path.suffix.lower() not in suffixes):
                continue
            lowered = path.read_text(encoding="utf-8").lower()
            checked += 1
            self.assertNotIn("netlify.app", lowered, path)
            self.assertNotIn("pour-landing", lowered, path)
        self.assertGreater(checked, 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
