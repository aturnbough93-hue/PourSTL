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
