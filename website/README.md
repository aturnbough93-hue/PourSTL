# PourSTL website

Static site for the PourSTL iPhone app and its account-free browser app. Local preview needs no install.
Production is built by `scripts/build_website.py` and hosted on Cloudflare Pages.

## Run it

```bash
cd website
python3 -m http.server 8080
# open http://localhost:8080
```

Use the HTTP server so root-relative links and icons resolve correctly. No
package installation is required; images and scripts are served locally.
This server exposes the app as `/try.html`, not Pages' clean `/try` route, so
the service worker's `/try` cache entry cannot be installed and the Home Screen
start URL does not resolve. Use the Cloudflare Pages branch preview to verify
the clean app route, offline cache, and Home Screen install.

## Cloudflare Pages

Cloudflare Pages hosts the website in the **pourstl** project. The canonical
site is **https://pourstl.com**, including `/privacy`, `/support`, and `/try`.
The project name stays `pourstl`. `pourstl.pages.dev` remains the assigned
Pages hostname and is not the canonical URL. The Pages setup does not add
redirects or DNS changes. The site uses the security headers in
`website/_headers`.

The [Bar Assistant Worker](../workers/bar-assistant/README.md) at
`assistant.pourstl.com` is deployed separately from Pages. Neither the
marketing site nor PourSTL Web calls it, and browser data is not sent to it.

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

Keep iPhone download calls to action pointed at the status section until a public distribution link exists. The web app is available now at `/try`. Phone frames are illustrative previews, not simulator screenshots. Planned features must stay clearly labeled.

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

## PourSTL Web

`/try` opens the web app. It includes the native recipe catalog, custom recipes,
favorites, recipe matching, inventory, shopping, scaling, and a prep timer.
Scaling goes up to 24 servings; Pro costing and CSV prep sheets are iPhone-only.
The web app saves state in the browser, shares saved changes across tabs on the
same origin, and migrates existing demo inventory and shopping data.

In My Bar, `Rye` counts as rye whiskey for recipe matching, including for
previously saved `Rye` entries. It does not count as bourbon.

**Bar Assistant** in the header uses local rules and this browser's recipes and
My Bar to answer supported questions about what you can make, ingredient
stand-ins, and scaled measures. Stock checks use ingredient presence, not
quantities or dietary suitability. Questions and replies are not sent or saved;
closing the dialog clears them.

The service worker is scoped to `/try`, not the marketing or support pages.
It caches the app, including the assistant script, after the first load. A
production build versions the cache using the static site's content.

When verifying `/try` on a Pages preview, check these flows:

- After the app has cached, go offline and reload `/try` to verify that the
  app loads from cache. Then open **Bar Assistant** and try “What can I make?”
  or “Scale the Negroni for 4.” Close with **Done** and reopen to confirm the
  conversation cleared.
- At phone widths (700px and below), recipe search and results come before the
  recipe detail and My Bar. **My Bar & tools** jumps to the bar panel;
  **Back to recipes** in the detail returns focus to the selected result.
- With no search text, an empty **Favorites** filter explains how to save a
  favorite and offers **Browse all drinks**. An empty **Can make** filter
  prompts you to stock ingredients and offers **Open My Bar**. A search with
  no results offers **Clear search and filters** instead.
- In recipe detail, look for **Missing** beside each unstocked required
  ingredient. In the custom recipe editor at 320px, check that the **Optional**
  checkbox is visible and usable.
- On desktop, check that **Ingredient to stock** stays visible above the My Bar
  input while you type. On desktop and mobile, **Seconds** and **Start timer**
  should switch to **Time left** and **Stop timer** while the prep timer runs.
  When it finishes, the setup controls return with **Time’s up**.

Use `python3 scripts/export_web_catalog.py` to refresh the browser catalog after
changing the native seed recipes. Run `node scripts/test_demo.cjs` for app logic
and `python3 scripts/check_website.py` for website checks. Verify the public CTA
at https://pourstl.com and the app at https://pourstl.com/try.
