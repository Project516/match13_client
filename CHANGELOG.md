# Changelog

## Unreleased

## 0.1.0

- First release. Covers all nine routes of the match13 read API: team season,
  team events, event teams, event matches, match, event simulation, season
  teams, district standings and regional pool standings.
- Bearer-key auth, RFC 9457 problem bodies surfaced as `Match13ApiException`,
  and retries on 429 and 5xx that honour the API's `retryAfter`.
- Models verified against the published OpenAPI schema and response examples.
  Not yet exercised against a live 200; see "Verification status" in the
  README.
