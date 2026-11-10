"""Regression tests for Cloudflare metadata, preview indexing, and output safety."""

import hashlib
from pathlib import Path
import tempfile
import unittest

from build_website import (MARKER, OLD_ORIGIN, REPOSITORY, build_site,
                           deployment_settings, rewrite_metadata, validate_origin)


def fingerprints(directory):
    return {str(path.relative_to(directory)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in directory.rglob("*") if path.is_file()}


class CloudflareBuildTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.output = Path(self.temporary.name) / "dist"
        self.source = REPOSITORY / "website"

    def test_production_build_rewrites_metadata_and_preserves_source_assets_headers(self):
        before = fingerprints(self.source)
        origin = "https://confirmed-pour.pages.dev"
        build_site(self.source, self.output, origin)
        self.assertEqual(fingerprints(self.source), before)
        for name in ["index.html", "privacy.html", "try.html", "support.html", "sitemap.xml", "robots.txt"]:
            output = (self.output / name).read_text()
            self.assertNotIn(OLD_ORIGIN, output)
            self.assertIn(origin, output)
        self.assertEqual((self.output / "_headers").read_bytes(), (self.source / "_headers").read_bytes())
        self.assertEqual((self.output / "site.js").read_bytes(), (self.source / "site.js").read_bytes())
        self.assertEqual(fingerprints(self.output / "assets"), fingerprints(self.source / "assets"))
        touch_icon = (self.source / "assets" / "apple-touch-icon.png").read_bytes()
        self.assertEqual((self.output / "apple-touch-icon.png").read_bytes(), touch_icon)
        self.assertEqual((self.output / "apple-touch-icon-precomposed.png").read_bytes(), touch_icon)
        self.assertFalse((self.output / "README.md").exists())
        self.assertTrue((self.output / MARKER).exists())
        self.assertTrue((self.output / "404.html").is_file())
        for page in ("privacy", "try", "support"):
            html = (self.output / f"{page}.html").read_text()
            sitemap = (self.output / "sitemap.xml").read_text()
            self.assertIn(f'href="{origin}/{page}"', html)
            self.assertIn(f'property="og:url" content="{origin}/{page}"', html)
            self.assertNotIn(f"{origin}/{page}.html", html)
            self.assertIn(f"<loc>{origin}/{page}</loc>", sitemap)
            self.assertNotIn(f"{origin}/{page}.html", sitemap)
            self.assertIn(f'content="{origin}/assets/og-image.jpg"', html)
        self.assertEqual((self.output / "demo-core.js").read_bytes(), (self.source / "demo-core.js").read_bytes())

    def test_metadata_rewriting_preserves_copy_and_regular_links(self):
        html = f'<p>{OLD_ORIGIN}/privacy.html</p><a href="{OLD_ORIGIN}/privacy.html">Old site</a>'
        self.assertEqual(rewrite_metadata(html, "https://barpour.pages.dev"), html)

    def test_infers_stable_project_origin_and_explicit_custom_domain_takes_precedence(self):
        for deployment in ["https://abc123.confirmed-pour.pages.dev", "https://feature.confirmed-pour.pages.dev/", "https://confirmed-pour.pages.dev"]:
            self.assertEqual(deployment_settings({"CF_PAGES_URL": deployment, "CF_PAGES_BRANCH": "main"}),
                             ("https://confirmed-pour.pages.dev", False))
        self.assertEqual(deployment_settings({"SITE_URL": "https://pour.example.com/", "CF_PAGES_URL": "https://hash.project.pages.dev"}),
                         ("https://pour.example.com", False))

    def test_preview_is_noindex_with_production_canonical_and_preserved_security(self):
        origin, preview = deployment_settings({"CF_PAGES_URL": "https://hash.confirmed-pour.pages.dev", "CF_PAGES_BRANCH": "feature/review"})
        self.assertTrue(preview)
        build_site(self.source, self.output, origin, preview)
        headers = (self.output / "_headers").read_text()
        self.assertIn("X-Robots-Tag: noindex, nofollow", headers)
        self.assertIn("Content-Security-Policy:", headers)
        self.assertEqual((self.output / "robots.txt").read_text(), "User-agent: *\nDisallow: /\n")
        self.assertIn('href="https://confirmed-pour.pages.dev/"', (self.output / "index.html").read_text())
        self.assertFalse(deployment_settings({"SITE_URL": origin, "CF_PAGES_BRANCH": "release", "SITE_PRODUCTION_BRANCH": "release"})[1])

    def test_rejects_invalid_or_missing_origins(self):
        for value in ["http://example.com", "https://user:pass@example.com", "https://example.com/path", "https://example.com:443", "https://example.com?x=1", "https://example.com?", "https://example.com/#anchor", "https://example.com#", "https://bad_host.example", "https://example.com\n", "https://exam\nple.com", "https://example.com%0aevil", "https://[broken"]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                validate_origin(value)
        for environment in [{}, {"CF_PAGES_URL": "https://example.com"}, {"CF_PAGES_URL": "https://pages.dev"}]:
            with self.subTest(environment=environment), self.assertRaises(ValueError):
                deployment_settings(environment)

    def test_repeat_build_removes_stale_generated_files(self):
        build_site(self.source, self.output, "https://first.example.com")
        (self.output / "stale.html").write_text("old")
        build_site(self.source, self.output, "https://second.example.com")
        self.assertFalse((self.output / "stale.html").exists())
        self.assertIn("https://second.example.com", (self.output / "index.html").read_text())

    def test_refuses_unrecognized_output_source_or_symlink_without_deleting_data(self):
        self.output.mkdir()
        keep = self.output / "keep.txt"
        keep.write_text("user work")
        with self.assertRaises(ValueError):
            build_site(self.source, self.output, "https://example.com")
        self.assertEqual(keep.read_text(), "user work")
        for output in [self.source, self.source.parent, self.source / "nested-output"]:
            with self.subTest(output=output), self.assertRaises(ValueError):
                build_site(self.source, output, "https://example.com")
        symlink = Path(self.temporary.name) / "linked-output"
        symlink.symlink_to(self.output, target_is_directory=True)
        with self.assertRaises(ValueError):
            build_site(self.source, symlink, "https://example.com")
        self.assertEqual(keep.read_text(), "user work")


if __name__ == "__main__":
    unittest.main(verbosity=2)
