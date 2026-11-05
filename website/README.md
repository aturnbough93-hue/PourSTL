# Pour website

Static marketing/landing page for the Pour iOS app. No build step, no dependencies.

## Run it

```bash
cd website
python3 -m http.server 8080
# open http://localhost:8080
```

Or just open `index.html` in a browser — everything is local (images in `assets/`).

## Cloudflare Pages

Cloudflare Pages is the target host. It supports the current static files,
GitHub deployments, preview deployments, HTTPS, and the existing security headers.
The requested project name is **barpour**, with **https://barpour.pages.dev** as
the desired production address. Cloudflare must confirm that name is available;
do not silently choose a suffix or publish another address.

### Connect the account once

In the [Cloudflare dashboard](https://dash.cloudflare.com/), open **Workers &
Pages**, create a **Pages** project, and choose **Import an existing Git
repository / Connect to Git**. Authorize access to `aturnbough93-hue/pour` and
use these settings:

| Setting | Value |
| --- | --- |
| Project name | `barpour` |
| Repository | `aturnbough93-hue/pour` |
| Production branch | `main` |
| Framework preset | None |
| Root directory | Leave blank (repository root) |
| Build command | `python3 scripts/build_website.py` |
| Build output directory | `dist` |

The initial GitHub authorization must be done by the account owner. This repo
does not require Cloudflare credentials in the website, GitHub secrets, or an
API token for Git-connected deployment. Do not create a Direct Upload project
first: that project type cannot later be converted to Git integration.

`wrangler.toml` records the requested project name and generated output directory.
The build is dependency-free Python; it copies public files and sets canonical,
social-image, sitemap, and robots URLs for the actual Pages project. Cloudflare
provides `CF_PAGES_URL` and `CF_PAGES_BRANCH` automatically. A deployment hash or
preview branch address is never used as the production canonical origin.

Set `SITE_URL` to an HTTPS origin only when using a verified custom domain, or
when explicitly overriding the canonical production origin. The default
production branch is `main`; `SITE_PRODUCTION_BRANCH` overrides it if needed.
Preview builds emit noindex headers and robots rules. Neither variable is secret.

### Verify and cut over

1. Wait for Cloudflare to report the first successful production deployment and
   confirm the actual address is `https://barpour.pages.dev`.
2. Check the homepage, privacy page, images, JavaScript, navigation, and an unknown
   path (real 404 response). Confirm the response headers include CSP, nosniff,
   frame restrictions, and the permissions policy.
3. Check canonical/social URLs, `robots.txt`, and `sitemap.xml` use the new host.
   Cloudflare redirects `.html` routes to extensionless routes, so the generated
   privacy canonical and sitemap use `/privacy`.
4. Only after those checks, add a Netlify-only 301 redirect in `netlify.toml`:

   ```toml
   [[redirects]]
     from = "/*"
     to = "https://barpour.pages.dev/:splat"
     status = 301
     force = true
   ```

   Deploy that configuration to the old Netlify project. Do not put this rule in
   the shared `website/_redirects` file, which could create a loop on Cloudflare.
   Keep the old site available for incoming links. Its `netlify.app` address is
   owned by Netlify and cannot be moved through DNS.

The Netlify configuration and source-page metadata remain intact until live
cutover is verified. Cloudflare publishes `dist`, where the build supplies the
new metadata; Netlify currently publishes `website`.

### Local build checks

```bash
python3 scripts/check_website.py
python3 -m unittest discover -s scripts -p 'test_build_website.py' -v
SITE_URL=https://barpour.pages.dev python3 scripts/build_website.py
python3 -m http.server 8080 --directory dist
```

This local build demonstrates the requested address in generated metadata; it
does not reserve a Pages name or deploy a site. Generated `dist/` is ignored by
Git. Existing directories without the generator marker are never overwritten.

## Content and privacy

The app is in development. Keep download calls to action pointed at the status section until a public distribution link exists. Phone frames are illustrative previews, not simulator screenshots. Planned features must stay clearly labeled.

`privacy.html` describes current data handling. Update it when adding network services, analytics, accounts, permissions, or backup/export behavior. The site has no third-party scripts or dependencies.

## Hosting security headers

Cloudflare Pages reads `_headers` from the generated publish directory; the
same format also works on the current Netlify site. It restricts scripts and
assets to this origin, blocks network API calls and framing, and disables
camera/microphone/geolocation permissions. Inline styles remain allowed because
the static page uses inline presentation styles; inline scripts are blocked.
`python3 -m http.server` does not apply these headers. Check the real deployed
response headers after publishing.

## Interactive testing surface

`try.html` is a working six-recipe browser demo, with local inventory, search,
matching, serving/unit controls, and a deduplicated shopping/restocking flow.
Its state lives only in that browser; it does not sync with the native app.
Reset demo requests confirmation and clears this demo state. Clipboard failures
show selectable recipe text instead of claiming a successful copy. The current
CSP still permits no remote API connections.

Run its logic regression suite with `node scripts/test_demo.cjs`. After Cloudflare
activation, test `/try` on the confirmed Pages address; opening a browser demo
does not validate native persistence, haptics, iOS sharing, or StoreKit.
