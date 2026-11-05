#!/usr/bin/env python3
"""Build the static site for Cloudflare Pages without guessing its public URL.

Cloudflare: python3 scripts/build_website.py (output: dist/).
Local: SITE_URL=https://your-confirmed-domain.example python3 scripts/build_website.py

SITE_URL is an optional production-origin override, normally a confirmed custom
domain. Otherwise CF_PAGES_URL identifies the Pages project; deployment hashes
and branch prefixes are removed from its *.pages.dev hostname. Source files keep
their existing URLs until the replacement host is verified.
"""

import argparse
from pathlib import Path
import os
import re
import shutil
import tempfile
from urllib.parse import urlsplit


REPOSITORY = Path(__file__).resolve().parents[1]
OLD_ORIGIN = "https://barpour.netlify.app"
MARKER = ".pour-generated-site"
MARKER_CONTENT = "Pour static website build v1\n"
DNS_LABEL = re.compile(r"[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\Z")
TAG = re.compile(r"<(?:link|meta)\b[^>]*>", re.IGNORECASE)
ATTRIBUTE = re.compile(r'''([\w:-]+)\s*=\s*(["'])(.*?)\2''', re.DOTALL)


def validate_origin(value):
    """Accept an HTTPS DNS origin, excluding paths, ports, and credentials."""
    try:
        parsed = urlsplit(value)
        hostname = parsed.hostname or ""
        valid = (not any(character.isspace() for character in value)
                 and "?" not in value and "#" not in value and parsed.scheme == "https"
                 and parsed.username is None and parsed.password is None
                 and parsed.port is None and parsed.path in ("", "/")
                 and not parsed.query and not parsed.fragment
                 and len(hostname) <= 253 and len(hostname.split(".")) >= 2
                 and all(DNS_LABEL.fullmatch(label) for label in hostname.split(".")))
    except ValueError:
        valid = False
    if not valid:
        raise ValueError("Site URL must be an HTTPS origin with no path, port, credentials, query, or fragment")
    return f"https://{hostname}"


def deployment_settings(environment):
    explicit = environment.get("SITE_URL", "")
    if explicit:
        origin = validate_origin(explicit)
    else:
        deployment_url = environment.get("CF_PAGES_URL", "")
        if not deployment_url:
            raise ValueError("Set SITE_URL to a confirmed public origin, or build inside Cloudflare Pages (CF_PAGES_URL)")
        deployment_origin = validate_origin(deployment_url)
        labels = urlsplit(deployment_origin).hostname.split(".")
        if len(labels) < 3 or labels[-2:] != ["pages", "dev"]:
            raise ValueError("CF_PAGES_URL must identify a *.pages.dev deployment; use SITE_URL for a custom domain")
        origin = "https://" + ".".join(labels[-3:])
    branch = environment.get("CF_PAGES_BRANCH", "")
    production_branch = environment.get("SITE_PRODUCTION_BRANCH", "main")
    preview = bool(branch and branch != production_branch)
    return origin, preview


def rewrite_metadata(html, origin):
    """Rewrite public metadata only, leaving page copy and outbound links intact."""
    def rewrite_tag(match):
        tag = match.group()
        attributes = list(ATTRIBUTE.finditer(tag))
        values = {attribute[1].lower(): attribute[3] for attribute in attributes}
        target = ("href" if values.get("rel", "").lower() == "canonical" else
                  "content" if values.get("property", "").lower() in ("og:url", "og:image")
                  or values.get("name", "").lower() == "twitter:image" else None)
        for attribute in attributes:
            if attribute[1].lower() == target and attribute[3].startswith(OLD_ORIGIN + "/"):
                start, end = attribute.span(3)
                destination = origin + attribute[3][len(OLD_ORIGIN):]
                if target == "href" and destination in (origin + "/privacy.html", origin + "/try.html"):
                    destination = destination[:-5]
                return tag[:start] + destination + tag[end:]
        return tag
    return TAG.sub(rewrite_tag, html)


def build_site(source, output, origin, preview=False):
    """Create a complete site in a staging directory; never overwrite user files."""
    origin = validate_origin(origin)
    source = Path(source).resolve(strict=True)
    requested_output = Path(output)
    if requested_output.is_symlink():
        raise ValueError("Output must not be a symlink")
    output = requested_output.resolve()
    if output == source or output in source.parents or source in output.parents:
        raise ValueError("Output must be separate from the source directory and its ancestors")
    if output.exists():
        marker = output / MARKER
        if (not output.is_dir() or not marker.is_file() or marker.is_symlink()
                or marker.read_text() != MARKER_CONTENT):
            raise ValueError(f"Refusing to replace an unrecognized existing output directory: {output}")
    if any(path.is_symlink() for path in source.rglob("*")):
        raise ValueError("Website source must not contain symlinks")
    if not (source / "index.html").is_file():
        raise ValueError("Website source must contain index.html")
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=f".{output.name}-build-", dir=output.parent) as temporary:
        stage = Path(temporary) / "site"
        shutil.copytree(source, stage, ignore=shutil.ignore_patterns("README.md"))
        for page in stage.rglob("*.html"):
            page.write_text(rewrite_metadata(page.read_text(), origin))
        sitemap = stage / "sitemap.xml"
        sitemap.write_text(sitemap.read_text().replace(OLD_ORIGIN + "/", origin + "/")
                           .replace(origin + "/privacy.html", origin + "/privacy")
                           .replace(origin + "/try.html", origin + "/try"))
        robots = stage / "robots.txt"
        robots.write_text("User-agent: *\nDisallow: /\n" if preview else
                          robots.read_text().replace(OLD_ORIGIN + "/", origin + "/"))
        if preview:
            headers = stage / "_headers"
            lines = headers.read_text().splitlines()
            if "/*" not in lines:
                lines.append("/*")
            lines.insert(lines.index("/*") + 1, "  X-Robots-Tag: noindex, nofollow")
            headers.write_text("\n".join(lines) + "\n")
        (stage / MARKER).write_text(MARKER_CONTENT)
        backup = Path(temporary) / "previous"
        if output.exists():
            output.rename(backup)
        try:
            stage.rename(output)
        except OSError:
            if backup.exists():
                backup.rename(output)
            raise
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=REPOSITORY / "dist")
    args = parser.parse_args()
    try:
        origin, preview = deployment_settings(os.environ)
        output = build_site(REPOSITORY / "website", args.output, origin, preview)
    except (OSError, ValueError) as error:
        parser.exit(1, f"Website build failed: {error}\n")
    print(f"Built {output}: canonical origin {origin}; {'preview (noindex)' if preview else 'production'}")


if __name__ == "__main__":
    main()
