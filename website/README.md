# Pour website

Static marketing/landing page for the Pour iOS app. Local preview needs no install.
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

Cloudflare Pages is the production host. The project is **barpour** and its
assigned public address is **https://barpour-7hb.pages.dev**. The preferred
`barpour.pages.dev` name was already registered outside the authorized account;
it is not the deployment managed here. The site uses HTTPS and the security
headers in `website/_headers`.

### Production project

| Setting | Value |
| --- | --- |
| Project name | `barpour` |
| Assigned hostname | `barpour-7hb.pages.dev` |
| Source repository | `aturnbough93-hue/pour` |
| Deployment method | Wrangler direct upload |
| Production branch | `main` |
| Local build command | `SITE_URL=https://barpour-7hb.pages.dev python3 scripts/build_website.py` |
| Upload directory | `dist` |

GitHub pushes run quality checks. This Pages project currently uses direct
uploads; merging a PR does not automatically publish its website changes.
No Cloudflare token is stored in the repository. Authenticate with Wrangler in
your own environment, build the reviewed commit, and deploy:

```bash
npx --yes wrangler@4.158.0 login --device --browser=false --scopes account:read user:read pages:write
SITE_URL=https://barpour-7hb.pages.dev CF_PAGES_BRANCH=main python3 scripts/build_website.py
npx --yes wrangler@4.158.0 pages deploy dist --project-name barpour --branch main --force
```

In Wrangler 4.158, `--force` keeps this command on the existing Pages API rather
than delegating to the newer Workers deployment path. It does not remove the
project. Confirm the assigned hostname and account before deploying. Wrangler
records the commit and reports if the working tree is dirty.

`wrangler.toml` records the project name and generated output directory. The
build is dependency-free Python; it copies public files and sets canonical,
social-image, sitemap and robots URLs. A deployment hash or preview address is
never used as the production canonical origin. For a separately configured
Git-connected project, Cloudflare supplies `CF_PAGES_URL` and `CF_PAGES_BRANCH`;
the build also supports those variables.

Use `SITE_URL` for the confirmed public origin. The default production branch is
`main`; `SITE_PRODUCTION_BRANCH` overrides it if needed. Preview builds emit
noindex headers and robots rules. These build variables are not secrets.

### Check a deployment

1. Confirm production is `https://barpour-7hb.pages.dev`.
2. Check the homepage, privacy page, images, JavaScript, navigation, and an unknown
   path (real 404 response). Confirm the response headers include CSP, nosniff,
   frame restrictions, and the permissions policy.
3. Check canonical/social URLs, `robots.txt`, and `sitemap.xml` use
   `https://barpour-7hb.pages.dev`. Cloudflare serves `.html` files at extensionless
   paths (for example `/privacy.html` redirects to `/privacy`), so the generated
   canonical and sitemap use `/privacy`, `/try`, and `/support`.

There is no `website/_redirects` file. Cloudflare's own HTML routing already
covers those extensionless paths, so the repo does not add a second redirect
list. Do not add a site-wide redirect to `https://barpour-7hb.pages.dev` in a shared
`_redirects` file: Pages publishes that file, and redirecting every path would
loop on the production host.

Cloudflare publishes `dist`. Source pages in `website/` already use
`https://barpour-7hb.pages.dev`; the build rewrites that origin only when the
deployed origin differs.

### Local build checks

```bash
python3 scripts/check_website.py
python3 -m unittest discover -s scripts -p 'test_build_website.py' -v
SITE_URL=https://barpour-7hb.pages.dev python3 scripts/build_website.py
python3 -m http.server 8080 --directory dist
```

This local build writes `https://barpour-7hb.pages.dev` into generated metadata; it
does not deploy a site. Generated `dist/` is ignored by
Git. Existing directories without the generator marker are never overwritten.

## Content and privacy

The app is in development. Keep download calls to action pointed at the status section until a public distribution link exists. Phone frames are illustrative previews, not simulator screenshots. Planned features must stay clearly labeled.

`privacy.html` describes current data handling. Update it when adding network services, analytics, accounts, permissions, or backup/export behavior. The site has no third-party scripts or dependencies.

## Hosting security headers

Cloudflare Pages reads `_headers` from the generated publish directory. It
restricts scripts and assets to this origin, blocks network API calls and
framing, and disables camera/microphone/geolocation permissions. Inline styles
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
CSP still permits no remote API connections.

Run its logic regression suite with `node scripts/test_demo.cjs`. On production,
test `/try` at `https://barpour-7hb.pages.dev/try`. Opening a browser demo does not
validate native persistence, haptics, iOS sharing, or StoreKit.
