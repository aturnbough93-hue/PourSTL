# Connect pourstl.com to PourSTL

Canonical site: **https://pourstl.com**. It is live on Cloudflare Pages project
**pourstl**, including `/privacy` and `/support`. Registrar: **IONOS SE**. The
domain stays registered at IONOS while Cloudflare provides DNS and the Pages
website.

This repository does not change DNS records or add redirects. The Pages project
name stays `pourstl`. The assigned Pages hostname `pourstl.pages.dev` remains
the CNAME target for `@` and `www`; it is not the canonical URL.

Cloudflare Pages project **pourstl** serves `pourstl.com` and `www.pourstl.com`.
Current Wrangler permissions cannot create DNS zones or edit DNS records. Do
not paste API keys into issues or commits.

## Website records

Leave these records in place. This change does not create or edit them.
Preserve mail records, including existing MX, SPF, DKIM and verification
entries. Public DNS has shown priority-10 MX records for `mx00.ionos.com` and
`mx01.ionos.com`; keep them if using IONOS mail.

| Type | Name | Target | Proxy | TTL |
| --- | --- | --- | --- | --- |
| CNAME | `@` | `pourstl.pages.dev` | Proxied | Auto |
| CNAME | `www` | `pourstl.pages.dev` | Proxied | Auto |

Public NS for `pourstl.com` resolve to `amanda.ns.cloudflare.com` and
`matt.ns.cloudflare.com`. The original IONOS nameservers were
`ns1085.ui-dns.biz`, `ns1093.ui-dns.org`, `ns1095.ui-dns.com`, and
`ns1122.ui-dns.de`. This change does not replace nameservers.

## Checks for the live site

- Public NS records resolve to the assigned Cloudflare nameservers.
- Cloudflare shows the zone as Active and both Pages custom domains as Active.
- `https://pourstl.com` displays PourSTL with a valid certificate; `/try`,
  `/privacy`, `/support`, images and both root Apple touch icons work.
- `https://www.pourstl.com` works with a valid certificate, or redirects to the
  primary HTTPS host.
- An unknown URL returns a real 404; CSP, nosniff, permissions policy and framing
  restrictions are present.

Canonical and social metadata, robots, and the sitemap use `https://pourstl.com`.
Cloudflare deploys the `main` branch from GitHub to project `pourstl`.
See [the website README](../website/README.md) to preview and verify changes.
The iPhone app’s Settings → Support links use the canonical host:
**Get support** opens `https://pourstl.com/support`, **Privacy policy** opens
`https://pourstl.com/privacy`, and **PourSTL website** opens `https://pourstl.com`.
The store-recovery screen’s **Get help** also opens `https://pourstl.com/support`.
Do not add a redirect from the Pages hostname in this repo.

`https://pourstl.com`, `/privacy`, and `/support` already respond over HTTPS.
`https://www.pourstl.com` redirects to `https://pourstl.com/`. Record any later
DNS change in [HANDOFF.md](HANDOFF.md). This file does not make one.
