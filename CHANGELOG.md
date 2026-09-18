# Changelog

## Unreleased

## 0.2.0

- Add an optional `baseUrl` constructor parameter (default
  `Match13Client.defaultBaseUrl`, the unchanged
  `https://actions.match13.com`) so a caller can point the client at a
  proxy, for example one that adds CORS headers and the API key for a
  Flutter web build.
- Make `apiKey` optional: when it is null or empty, no `Authorization`
  header is sent, for callers where the proxy holds the key instead.

## 0.1.0

- First release. Covers all nine routes of the match13 read API: team season,
  team events, event teams, event matches, match, event simulation, season
  teams, district standings and regional pool standings.
- Bearer-key auth, RFC 9457 problem bodies surfaced as `Match13ApiException`,
  and retries on 429 and 5xx that honour the API's `retryAfter`.
- Models checked against bodies captured off the live API, with all nine
  routes run end to end through the client on 2026-09-17.
