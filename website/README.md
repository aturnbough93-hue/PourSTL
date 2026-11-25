# PourSTL website

Static marketing/landing page for the PourSTL iOS app. Local preview needs no install.
Production is built by `scripts/build_website.py` and hosted on Cloudflare Pages.

## Run it

```bash
cd website
python3 -m http.server 8080
# open http://localhost:8080
```

Use the HTTP server so root-relative links and icons resolve correctly. No
package installation is required; images and scripts are served locally.

## Cloudflare Pages

Cloudflare Pages hosts the website in the **pourstl** project. The canonical
site is **https://pourstl.com**, including `/privacy`, `/support`, and `/try`.
The project name stays `pourstl`. `pourstl.pages.dev` remains the assigned
Pages hostname and is not the canonical URL. This repo does not add redirects
or DNS changes. The site uses the security headers in `website/_headers`.

### Production project

| Setting | Value |
| --- | --- |
| Project name | `pourstl` |
| Canonical site | `https://pourstl.com` |
| Assigned Pages hostname | `pourstl.pages.dev` |
| Source repository | `aturnbough93-hue/PourSTL` |
| Deployment method | GitHub integration |
| Production branch | `main` |
| Cloudflare build command | `python3 scripts/build_website.py` |
| Build output directory | `dist` |

Cloudflare builds preview branches from GitHub and publishes changes to `main`
to `pourstl.com`. Review the branch preview and GitHub quality checks before
merging. To reproduce the production build locally, run:

```bash
SITE_URL=https://pourstl.com CF_PAGES_BRANCH=main python3 scripts/build_website.py
```

The build writes `https://pourstl.com` into public metadata. Source
pages already use that origin. A build does not configure DNS, attach a custom
domain, add a redirect, or provision its HTTPS certificate. A Cloudflare build
that omits `SITE_URL` maps the `pourstl.pages.dev` project hostname, including
deployment hashes and branch prefixes, to `https://pourstl.com`. Other
`*.pages.dev` projects keep their own project origin. An explicit `SITE_URL`
still overrides that mapping.

`wrangler.toml` records the project name and generated output directory. The
build is dependency-free Python; it copies public files and sets canonical,
social-image, sitemap and robots URLs. A deployment hash or preview address is
never used as the production canonical origin. Cloudflare supplies
`CF_PAGES_URL` and `CF_PAGES_BRANCH` for Git-connected builds.

Use `SITE_URL` for the confirmed public origin. The default production branch is
`main`; `SITE_PRODUCTION_BRANCH` overrides it if needed. Preview builds emit
noindex headers and robots rules. These build variables are not secrets.

Custom-domain connection steps are in [docs/DOMAIN_SETUP.md](../docs/DOMAIN_SETUP.md).

### Check a deployment

1. Confirm `https://pourstl.com` serves PourSTL, including `/privacy` and
   `/support`, with a valid HTTPS certificate.
2. Check the homepage, privacy page, images, JavaScript, navigation, and an unknown
   path (real 404 response). Confirm the response headers include CSP, nosniff,
   frame restrictions, and the permissions policy.
3. Check canonical/social URLs, `robots.txt`, and `sitemap.xml` use
   `https://pourstl.com`.
   Cloudflare serves `.html` files at extensionless
   paths (for example `/privacy.html` redirects to `/privacy`), so the generated
   canonical and sitemap use `/privacy`, `/try`, and `/support`.

There is no `website/_redirects` file. Cloudflare's own HTML routing already
covers those extensionless paths, so the repo does not add a second redirect
list. Do not add a site-wide redirect to `https://pourstl.com` in a shared
`_redirects` file: Pages publishes that file, and redirecting every path would
loop on the production host.

Cloudflare publishes `dist`. Source pages in `website/` already use
`https://pourstl.com`; the build rewrites that origin only when the deployed
origin differs.

### Local build checks

```bash
python3 scripts/check_website.py
python3 -m unittest discover -s scripts -p 'test_build_website.py' -v
SITE_URL=https://pourstl.com python3 scripts/build_website.py
python3 -m http.server 8080 --directory dist
```

This local build writes `https://pourstl.com` into generated metadata; it
does not deploy a site. Generated `dist/` is ignored by
Git. Existing directories without the generator marker are never overwritten.

## Content and privacy

The app is in development. Keep download calls to action pointed at the status section until a public distribution link exists. Phone frames are illustrative previews, not simulator screenshots. Planned features must stay clearly labeled.

`privacy.html` describes current data handling. Update it when adding network services, analytics, accounts, permissions, or backup/export behavior. The repository does not vendor third-party scripts. The content security policy allows the host to inject Cloudflare Web Analytics and blocks other remote APIs.

## Hosting security headers

Cloudflare Pages reads `_headers` from the generated publish directory. It
allows this origin plus Cloudflare Web Analytics
(`https://static.cloudflareinsights.com` for scripts, and `'self'` plus
`https://cloudflareinsights.com` for connections). Proxied automatic injection
posts the beacon to this site's `/cdn-cgi/rum`, which needs `'self'`. Other
network calls and framing stay blocked, and camera, microphone, geolocation,
and payment permissions stay disabled. Inline styles
remain allowed because
the static page uses inline presentation styles; inline scripts are blocked.
`python3 -m http.server` does not apply these headers. Check the real deployed
response headers after publishing.

## Interactive testing surface

`try.html` is a working six-recipe browser demo, with local inventory, search,
matching, serving/unit controls, and a deduplicated shopping/restocking flow.
Its state lives only in that browser; it does not sync with the native app.
Reset demo requests confirmation and clears this demo state. Clipboard failures
show selectable recipe text instead of claiming a successful copy. The current
CSP allows Cloudflare Web Analytics and still blocks other remote APIs.

Run its logic regression suite with `node scripts/test_demo.cjs`. On production,
test `/try` at `https://pourstl.com/try`. Opening a browser demo does not
validate native persistence, haptics, iOS sharing, or StoreKit.
