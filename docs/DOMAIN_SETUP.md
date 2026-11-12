# Connect pourstl.com to PourSTL

Future custom domain: **https://pourstl.com**. Current live primary:
**https://pourstl.pages.dev**. The owner is handling DNS and deferred the switch. Registrar: **IONOS SE**. The domain stays registered
at IONOS while Cloudflare provides DNS and the Pages website.

Cloudflare Pages project **pourstl** already has `pourstl.com` and
`www.pourstl.com` attached. Their DNS/TLS validation is pending. Current Wrangler
permissions cannot create DNS zones or edit DNS records; the account owner must
complete those dashboard steps. Do not paste API keys into issues or commits.

## Cloudflare

1. In the authorized account, add **pourstl.com** and choose the **Free** plan.
2. Import/review existing DNS records. Set the website records below. Replace
   conflicting A/AAAA/CNAME website records only for `@` and `www`.
3. Preserve mail records, including existing MX, SPF, DKIM and verification
   entries. Public DNS currently shows priority-10 MX records for
   `mx00.ionos.com` and `mx01.ionos.com`; keep them if using IONOS mail.
4. Copy the **two nameservers assigned to pourstl.com by Cloudflare**. They end
   in `.ns.cloudflare.com`; obtain their actual values from the domain dashboard.

| Type | Name | Target | Proxy | TTL |
| --- | --- | --- | --- | --- |
| CNAME | `@` | `pourstl.pages.dev` | Proxied | Auto |
| CNAME | `www` | `pourstl.pages.dev` | Proxied | Auto |

The original IONOS nameservers were `ns1085.ui-dns.biz`, `ns1093.ui-dns.org`,
`ns1095.ui-dns.com`, and `ns1122.ui-dns.de`. Those are the old registrar values,
not the two Cloudflare nameservers to enter.

## IONOS

Open **Domains & SSL → pourstl.com → Nameservers → Use custom nameservers**.
Replace the existing nameserver set with the two values Cloudflare assigned,
save the change, and complete any IONOS confirmation. DNS checks may take time
after both the Cloudflare records and IONOS nameserver change are saved.

## Verify before declaring the domain live

- Public NS records resolve to the assigned Cloudflare nameservers.
- Cloudflare shows the zone as Active and both Pages custom domains as Active.
- `https://pourstl.com` displays PourSTL with a valid certificate; `/try`,
  `/privacy`, `/support`, images and both root Apple touch icons work.
- `https://www.pourstl.com` works with a valid certificate, or redirects to the
  primary HTTPS host.
- An unknown URL returns a real 404; CSP, nosniff, permissions policy and framing
  restrictions are present.

The live fallback currently uses `pourstl.pages.dev` in canonical/social metadata.
Once the custom domain is active, deploy the reviewed main commit with
`SITE_URL=https://pourstl.com CF_PAGES_BRANCH=main python3 scripts/build_website.py`,
then upload `dist` to project `pourstl` as documented in
[the website README](../website/README.md). Verify canonical/social metadata,
robots and sitemap use `https://pourstl.com`. Keep the Pages alias usable as a
fallback; the app's Privacy Policy link uses its verified policy page.

Record the actual verification time, deployment commit and any remaining DNS
status in [HANDOFF.md](HANDOFF.md). Domain registration or a pending status alone
does not establish that the custom website is live.
