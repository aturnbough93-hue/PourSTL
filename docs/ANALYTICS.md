# PourSTL web analytics

This document is the repeatable reporting reference for PourSTL Web. It separates production usage from QA, bots, probes, and preview traffic without deleting the underlying data.

## First-party feature events

`/try` sends coarse feature-action counts to the same-origin Pages Function at `/api/analytics`. The function writes to the Cloudflare Analytics Engine dataset `pourstl_feature_events` through the `FEATURE_ANALYTICS` binding configured in the root `wrangler.toml`.

Allowed event names are:

- `app_open`
- `recipe_view`
- `my_bar_add`
- `my_bar_remove`
- `shopping_list_add`
- `custom_recipe_save`
- `serving_scale`
- `unit_toggle`
- `timer_start`
- `timer_complete`
- `assistant_open`
- `assistant_turn_success`
- `assistant_turn_failure`

The privacy boundary is intentional: events do not include recipe names or IDs, ingredient names or IDs, inventory or shopping-list contents, assistant prompts or answers, cookies, persistent user identifiers, fingerprints, or precise location.

Analytics Engine field mapping:

| Field | Meaning |
| --- | --- |
| `index1` | event name |
| `blob1` | surface, currently `web_try` |
| `blob2` | coarse path, `/try` or `/try.html` |
| `blob3` | environment, `production` for `pourstl.com`/`www.pourstl.com` and `preview` otherwise |
| `double1` | count contribution, currently `1` |

### Feature usage by day

Cloudflare Analytics SQL dataset interface:

```sql
SELECT
  toDate(timestamp) AS date,
  index1 AS event,
  sum(double1) AS est_events
FROM events.analyticsEngine.pourstl_feature_events
WHERE accountTag = '451ace7be1a6f2b9a8a6f0e4d5529c06'
  AND timestamp > now() - INTERVAL 30 DAY
  AND blob3 = 'production'
GROUP BY date, event
ORDER BY date DESC, est_events DESC
LIMIT 500
FORMAT JSON
```

### Feature usage funnel

This compares opens with meaningful actions. It is count-based, not user-based, because the implementation intentionally has no persistent user identifiers.

```sql
SELECT
  index1 AS event,
  sum(double1) AS est_events
FROM events.analyticsEngine.pourstl_feature_events
WHERE accountTag = '451ace7be1a6f2b9a8a6f0e4d5529c06'
  AND timestamp > now() - INTERVAL 30 DAY
  AND blob3 = 'production'
GROUP BY event
ORDER BY est_events DESC
LIMIT 100
FORMAT JSON
```

### Assistant success ratio

`assistant_turn_success` and `assistant_turn_failure` measure the local rule-based assistant in PourSTL Web, not the separate `assistant.pourstl.com` Worker API.

```sql
SELECT
  toDate(timestamp) AS date,
  sumIf(double1, index1 = 'assistant_turn_success') AS est_successes,
  sumIf(double1, index1 = 'assistant_turn_failure') AS est_failures
FROM events.analyticsEngine.pourstl_feature_events
WHERE accountTag = '451ace7be1a6f2b9a8a6f0e4d5529c06'
  AND timestamp > now() - INTERVAL 30 DAY
  AND blob3 = 'production'
  AND index1 IN ('assistant_turn_success', 'assistant_turn_failure')
GROUP BY date
ORDER BY date DESC
LIMIT 60
FORMAT JSON
```

## RUM production pageloads

Use RUM pageloads for page-level adoption; raw HTTP requests are dominated by scanner/probe and edge-cache noise. This query labels headless/QA traffic separately rather than deleting it.

```sql
SELECT
  toDate(timestamp) AS date,
  requestPath,
  if(requestHost LIKE '%.pages.dev', 'preview',
    if(userAgentBrowser = 'ChromeHeadless', 'headless_qa',
      if(requestPath LIKE '/qa%', 'explicit_qa', 'production_non_headless'))) AS traffic_class,
  sum(sampleInterval) AS est_pageloads
FROM events.rumPageloadEvents
WHERE timestamp > now() - INTERVAL 30 DAY
  AND (requestHost IN ('pourstl.com', 'www.pourstl.com') OR requestHost LIKE '%.pages.dev')
GROUP BY date, requestPath, traffic_class
ORDER BY date DESC, est_pageloads DESC
LIMIT 500
FORMAT JSON
```

Production-only `/try` trend:

```sql
SELECT
  toDate(timestamp) AS date,
  sum(sampleInterval) AS est_try_pageloads
FROM events.rumPageloadEvents
WHERE timestamp > now() - INTERVAL 30 DAY
  AND requestHost IN ('pourstl.com', 'www.pourstl.com')
  AND requestPath IN ('/try', '/try.html')
  AND userAgentBrowser != 'ChromeHeadless'
GROUP BY date
ORDER BY date DESC
LIMIT 60
FORMAT JSON
```

## Raw HTTP noise query

Use this only to understand noise; do not use raw HTTP counts as adoption. It separately labels exploit/probe paths and edge/internal request sources.

```sql
SELECT
  toDate(timestamp) AS date,
  if(clientRequestPath LIKE '/wp-admin%', 'probe_wp_admin',
    if(clientRequestPath LIKE '%/.env%', 'probe_env',
      if(requestSource = 'edgeWorkerCacheAPI', 'edge_cache_internal',
        if(clientRequestHttpHost LIKE '%.pages.dev', 'preview', 'other')))) AS traffic_class,
  sum(sampleInterval) AS est_requests
FROM events.httpRequests
WHERE timestamp > now() - INTERVAL 7 DAY
  AND (clientRequestHttpHost IN ('pourstl.com', 'www.pourstl.com') OR clientRequestHttpHost LIKE '%.pages.dev')
GROUP BY date, traffic_class
ORDER BY date DESC, est_requests DESC
LIMIT 200
FORMAT JSON
```

## Separate Bar Assistant Worker API

Worker invocations are not product feature usage. The dedicated Worker returns 404 for every path except `/v1/assistant/turn`, so status must be part of any report.

```sql
SELECT
  toDate(timestamp) AS date,
  httpResponseStatus,
  sum(sampleInterval) AS est_invocations
FROM events.workersInvocations
WHERE timestamp > now() - INTERVAL 30 DAY
  AND scriptName = 'pourstl-bar-assistant'
GROUP BY date, httpResponseStatus
ORDER BY date DESC, est_invocations DESC
LIMIT 200
FORMAT JSON
```

## Interpretation guardrails

- Dates are UTC; the current day is partial until the UTC day closes.
- RUM pageloads and feature events are counts, not unique people or sessions.
- ChromeHeadless and `/qa60-missing-page` are useful for QA verification but must not be presented as customer adoption.
- Preview hosts (`*.pages.dev`) are useful for validating a branch but must be separated from production.
- A day with few or no events after deployment may mean low usage, blocked beacons, or insufficient time since deployment; do not infer exact user counts.
- Revenue remains unavailable until Stripe, App Store Connect, RevenueCat, or another payment/subscription source is connected.
