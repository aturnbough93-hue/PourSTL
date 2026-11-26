#!/usr/bin/env python3
"""Dependency-free static regression checks. Run: python3 scripts/check_website.py.

These checks complement rendered browser QA; they do not prove WCAG conformance
or that the hosting provider has applied the response-header configuration.
"""

from html.parser import HTMLParser
from pathlib import Path
import re
import subprocess
import sys
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


def csp_directives(policy):
    """Split a CSP into directive name -> source tokens."""
    directives = {}
    for directive in policy.split(";"):
        tokens = directive.split()
        if tokens:
            directives[tokens[0]] = tokens[1:]
    return directives


_META_ATTRIBUTE = re.compile(r"""([\w:-]+)\s*=\s*(['"])(.*?)\2""", re.IGNORECASE | re.DOTALL)


def meta_csp_policies(html):
    """Return CSP policies from meta tags, keeping quoted keywords such as 'self'."""
    policies = []
    for tag in re.findall(r"<meta\b[^>]*>", html, flags=re.IGNORECASE):
        attributes = {match.group(1).lower(): match.group(3) for match in _META_ATTRIBUTE.finditer(tag)}
        if attributes.get("http-equiv", "").lower() == "content-security-policy" and "content" in attributes:
            policies.append(attributes["content"])
    return policies


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

    def test_recipe_return_is_a_button_for_the_results(self):
        page = self.pages[SITE / "try.html"]
        [(tag, attrs)] = [(tag, attrs) for tag, attrs in page.tags
                          if attrs.get("id") == "back-to-recipes"]
        self.assertEqual(tag, "button")
        self.assertEqual(attrs.get("type"), "button")
        self.assertEqual(attrs.get("aria-controls"), "recipes")
        self.assertNotIn("href", attrs)
        self.assertIn("recipes", page.ids)

    def test_try_css_custom_properties_are_defined(self):
        css = (SITE / "try.css").read_text()
        defined = set(re.findall(r"(--[a-z0-9-]+)\s*:", css))
        referenced = set(re.findall(r"var\(\s*(--[a-z0-9-]+)\s*\)", css))
        self.assertEqual(referenced - defined, set(), "Undefined CSS custom properties in try.css")

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
        self.assert_csp_allows_cloudflare_analytics(csp_directives(headers["Content-Security-Policy"]))
        self.assertNotIn("*", headers["Content-Security-Policy"])
        for source in self.sources.values():
            for policy in meta_csp_policies(source):
                self.assert_csp_allows_cloudflare_analytics(csp_directives(policy))
        self.assertEqual(headers["X-Content-Type-Options"].strip(), "nosniff")
        self.assertEqual(headers["X-Frame-Options"].strip(), "DENY")

    def test_meta_csp_quotes_do_not_truncate_keywords(self):
        policy = (
            "default-src 'none'; script-src 'self' https://static.cloudflareinsights.com; "
            "style-src 'self' 'unsafe-inline'; connect-src https://cloudflareinsights.com"
        )
        for html in (
            f'<meta http-equiv="Content-Security-Policy" content="{policy}">',
            f'<meta content="{policy}" http-equiv="Content-Security-Policy">',
            "<meta name=\"viewport\" content=\"width=device-width\">",
        ):
            with self.subTest(html=html):
                found = meta_csp_policies(html)
                if "Content-Security-Policy" not in html:
                    self.assertEqual(found, [])
                    continue
                self.assertEqual(found, [policy])
                directives = csp_directives(found[0])
                self.assertEqual(directives["default-src"], ["'none'"])
                self.assertEqual(directives["script-src"],
                                 ["'self'", "https://static.cloudflareinsights.com"])
                self.assertEqual(directives["style-src"], ["'self'", "'unsafe-inline'"])
                self.assertEqual(directives["connect-src"], ["https://cloudflareinsights.com"])

    def assert_csp_allows_cloudflare_analytics(self, directives):
        for name, value in {
                "default-src": ["'none'"],
                "script-src": ["'self'", "https://static.cloudflareinsights.com"],
                "connect-src": ["'self'", "https://cloudflareinsights.com"],
                "frame-ancestors": ["'none'"], "object-src": ["'none'"],
                "base-uri": ["'none'"], "form-action": ["'none'"]}.items():
            self.assertEqual(directives.get(name), value, name)

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
            self.assertEqual(parsed.netloc, "pourstl.com")
            paths.add(parsed.path)
            target = local_target(SITE / "index.html", parsed.path)
            self.assertTrue(target[0].is_file(), parsed.path)
        self.assertIn("/privacy.html", paths)
        self.assertIn("/support.html", paths)

    def test_subpages_share_the_existing_social_image(self):
        origin = "https://pourstl.com"
        image = f"{origin}/assets/og-image.jpg"
        for name in ("index.html", "privacy.html", "try.html", "support.html"):
            source = self.sources[SITE / name]
            with self.subTest(page=name):
                self.assertNotIn("pourstl.pages.dev", source)
                self.assertIn(f'rel="canonical" href="{origin}/', source)
                self.assertIn(f'property="og:image" content="{image}"', source)
                self.assertIn('property="og:title"', source)
                self.assertIn(f'property="og:url" content="{origin}/', source)
                self.assertIn('name="twitter:card" content="summary_large_image"', source)
                self.assertIn(f'name="twitter:image" content="{image}"', source)
        self.assertTrue((SITE / "assets" / "og-image.jpg").is_file())
        robots = (SITE / "robots.txt").read_text()
        sitemap = (SITE / "sitemap.xml").read_text()
        self.assertIn(f"Sitemap: {origin}/sitemap.xml", robots)
        self.assertNotIn("pourstl.pages.dev", robots)
        self.assertNotIn("pourstl.pages.dev", sitemap)

    def test_support_points_at_github_issues_without_an_email(self):
        source = self.sources[SITE / "support.html"]
        self.assertIn("https://github.com/aturnbough93-hue/PourSTL/issues", source)
        lowered = "\n".join(self.sources.values()).lower()
        self.assertNotIn("support@", lowered)
        self.assertNotIn("@example.com", lowered)

    def test_homepage_explains_both_tiers_and_links_to_the_web_app(self):
        homepage = self.sources[SITE / "index.html"]
        plans = re.search(r'<section id="plans".*?</section>', homepage, flags=re.DOTALL)
        self.assertIsNotNone(plans)
        for label in ("<h3>Free</h3>", "<h3>PourSTL Pro</h3>", "24 servings", "200 servings", "Recipe costing", "CSV prep sheets"):
            self.assertIn(label, plans.group(0))
        self.assertIn('class="btn btn-primary" href="try.html">Open web app', homepage)
        self.assertIn('href="try.html" class="btn btn-primary">Open web app', homepage)
        self.assertNotIn("hero-photo", homepage)
        self.assertNotIn(">App status<", homepage)
        self.assertEqual(homepage.count(">Related builds<"), 1)
        self.assertIn(
            '<span class="eyebrow"><span class="eyebrow-text">Built for service ·&nbsp;Private by default</span></span>',
            homepage,
        )
        self.assertNotIn("eyebrow-ios", homepage)
        self.assertRegex(
            homepage,
            r"@media\s*\(\s*max-width:\s*860px\s*\)\s*\{[^@]*?\.nav-status\s*\{[^}]*display:\s*none",
        )
        self.assertIn('href="#plans" class="btn btn-ghost">Compare Free &amp; Pro</a>', homepage)
        self.assertIn('<a href="#get">iPhone app availability</a>', homepage)

    def test_ios_requirement_stays_in_the_footer(self):
        requirement = "PourSTL requires an iPhone running iOS 17 or later."
        for name in ("index.html", "privacy.html", "support.html"):
            source = self.sources[SITE / name]
            with self.subTest(page=name):
                footer = re.search(r"<footer\b[^>]*>.*?</footer>", source, flags=re.IGNORECASE | re.DOTALL)
                self.assertIsNotNone(footer, "Footer missing")
                self.assertEqual(footer.group(0).count(requirement), 1)
                self.assertEqual(source.count(requirement), 1)
                outside = re.sub(r"<footer\b[^>]*>.*?</footer>", "", source, flags=re.IGNORECASE | re.DOTALL)
                self.assertNotIn("iOS 17", outside)
        eyebrow = re.search(r'<span class="eyebrow">.*?</span></span>', self.sources[SITE / "index.html"])
        self.assertIsNotNone(eyebrow)
        self.assertNotIn("iOS 17", eyebrow.group(0))
        self.assertNotIn("· ·", eyebrow.group(0))
        self.assertTrue(eyebrow.group(0).startswith('<span class="eyebrow"><span class="eyebrow-text">Built for service'))
        self.assertNotIn("requires an iPhone", self.sources[SITE / "try.html"])

    def test_web_catalog_stays_in_sync_with_native_recipes(self):
        subprocess.run([sys.executable, str(SITE.parent / "scripts/export_web_catalog.py"), "--check"], check=True)

    def test_website_privacy_discloses_optional_host_analytics(self):
        privacy = self.sources[SITE / "privacy.html"]
        homepage = self.sources[SITE / "index.html"]
        self.assertIn("cookieless Web Analytics", privacy)
        self.assertIn("does not upload your recipes, inventory, shopping list, or favorites", privacy)
        self.assertIn("cookieless website usage analytics", homepage)
        self.assertNotIn("does not add analytics", privacy)
        self.assertNotIn("website has no analytics scripts", homepage)

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
        """Only tracked files count. Ignored trees such as node_modules must not."""
        root = SITE.parent
        self.assertFalse((root / "netlify.toml").exists())
        self.assertTrue((SITE / "_headers").is_file())
        checked = 0
        for path in tracked_text_files(root):
            lowered = path.read_text(encoding="utf-8", errors="replace").lower()
            checked += 1
            self.assertNotIn("netlify.app", lowered, path)
            self.assertNotIn("pour-landing", lowered, path)
        self.assertGreater(checked, 0)


_TEXT_SUFFIXES = {".html", ".txt", ".xml", ".md", ".py", ".yml", ".yaml", ".toml", ".js", ".cjs", ".json"}
_UNTRACKED_DIRS = {
    ".git", "dist", "__pycache__", "node_modules", ".wrangler", "build", ".build",
    "DerivedData", ".venv", "venv",
}


def tracked_text_files(root):
    """Files this test is allowed to read.

    Prefer `git ls-files` so a local node_modules, virtualenv, or .wrangler
    tree cannot fail the check or crash it on a non-UTF-8 file. Fall back to a
    directory walk that skips those trees only when git is unavailable.
    """
    self_path = Path(__file__).resolve()
    try:
        listed = subprocess.run(
            ["git", "ls-files", "-z"],
            cwd=root,
            check=True,
            capture_output=True,
        )
    except (OSError, subprocess.CalledProcessError):
        listed = None
    if listed is not None:
        paths = []
        for name in listed.stdout.decode("utf-8", errors="replace").split("\0"):
            if not name:
                continue
            path = (root / name).resolve()
            if path == self_path or path.suffix.lower() not in _TEXT_SUFFIXES or not path.is_file():
                continue
            paths.append(path)
        return paths
    paths = []
    for path in root.rglob("*"):
        if (not path.is_file() or path.resolve() == self_path
                or any(part in _UNTRACKED_DIRS for part in path.parts)
                or path.suffix.lower() not in _TEXT_SUFFIXES):
            continue
        paths.append(path.resolve())
    return paths


if __name__ == "__main__":
    unittest.main(verbosity=2)
