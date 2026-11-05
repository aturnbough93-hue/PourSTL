# Pour website

Static marketing/landing page for the Pour iOS app. No build step, no dependencies.

## Run it

```bash
cd website
python3 -m http.server 8080
# open http://localhost:8080
```

Or just open `index.html` in a browser — everything is local (images in `assets/`).

## Deploy

The folder is a static site as-is. On Netlify, set the base directory to `website/` and leave the publish directory as `.` (it resolves relative to the base directory), or just drag the folder into Netlify Drop. No env vars or secrets needed.

## Content and privacy

The app is in development. Keep download calls to action pointed at the status section until a public distribution link exists. Phone frames are illustrative previews, not simulator screenshots. Planned features must stay clearly labeled.

`privacy.html` describes current data handling. Update it when adding network services, analytics, accounts, permissions, or backup/export behavior. The site has no third-party scripts or dependencies.

## Hosting security headers

Netlify reads `_headers` from this publish directory. It restricts scripts and assets to this origin, blocks network API calls and framing, and disables camera/microphone/geolocation permissions. Inline styles remain allowed because the static page uses inline presentation styles; inline scripts are blocked. `python3 -m http.server` does not apply these headers. Check the deployed response headers after publishing.
