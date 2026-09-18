# match13_client

A typed Dart client for the [match13](https://match13.com) read API: xP team
ratings, match forecasts, event simulations, and district and regional
standings for FRC. Pure Dart, so it works in Flutter apps, CLIs, and servers
alike.

```dart
import 'package:match13_client/match13_client.dart';

final client = Match13Client(apiKey: Platform.environment['MATCH13_KEY']!);
try {
  final event = await client.getEventTeams('2026txhou');
  final ranked = [...?event?.teams]
    ..sort((a, b) => b.xpEnd.compareTo(a.xpEnd));
} finally {
  client.close();
}
```

## Getting a key

Every route needs one. Make it on
[your account page](https://www.match13.com/account); you see it once, and one
account holds at most ten. The client sends it as
`Authorization: Bearer m13_live_...` on every request.

All the keys of one account share one allowance: 60 requests a minute, 1000 an
hour and 30000 a week. A 304 and an error count against it like anything else.

## Two things to know before you wire this up

**The API sends no CORS headers.** A browser cannot read it, so this client
cannot reach match13 directly from a Flutter web build. Call it from iOS,
Android, desktop or a server, where the key also stays out of sight, or point
`baseUrl` at a proxy that adds CORS headers and the key itself.

**match13 carries ratings, not a schedule.** There is no comp level, match
number, start time, alliance colour or score anywhere in it, and no team names.
Read those from The Blue Alliance and join on the match key or the team number.

## API reference

`Match13Client` targets `https://actions.match13.com` by default; pass
`baseUrl` to point it at a proxy instead, and omit `apiKey` (or pass an empty
string) when the proxy holds the key. Every method answers
`null` on 404, which is the normal answer for a team that did not play a
season, an event match13 does not carry, or an event the engine has not
simulated. Anything else outside 2xx throws `Match13ApiException`, carrying the
`type`, `title` and `detail` of the API's RFC 9457 problem body. Call `close()`
when you are done so the underlying HTTP client is released.

| Method | Endpoint | Returns |
| --- | --- | --- |
| `getTeamSeason(team, year)` | `GET /v1/teams/{team}/years/{year}` | `Match13TeamSeason?` |
| `getTeamEvents(team, year)` | `GET /v1/teams/{team}/years/{year}/events` | `Match13TeamEvents?` |
| `getEventTeams(eventKey)` | `GET /v1/events/{eventKey}/teams` | `Match13EventTeams?` |
| `getEventMatches(eventKey)` | `GET /v1/events/{eventKey}/matches` | `Match13EventMatches?` |
| `getMatch(matchKey)` | `GET /v1/matches/{matchKey}` | `Match13Match?` |
| `getEventSim(eventKey)` | `GET /v1/events/{eventKey}/sim` | `Match13EventSim?` |
| `getYearTeams(year)` | `GET /v1/years/{year}/teams` | `Match13YearTeams?` |
| `getDistrictTeams(code, year)` | `GET /v1/districts/{code}/{year}/teams` | `Match13DistrictTeams?` |
| `getRegionalTeams(year)` | `GET /v1/regionals/{year}/teams` | `Match13RegionalTeams?` |

- `getEventTeams` returns the rows in the order the API sent them, which is not
  rank order. Sort by `xpEnd` descending to rank an event's teams.
- `getYearTeams` pages: pages start at 1 and `nextPage` is `null` on the last
  one. Those rows carry no `components`; read a team on its own for those.
- `getTeamSeason`, `getTeamEvents`, `getEventMatches`, `getMatch` and
  `getYearTeams` take a `Match13Scope`. `season`, the API's default, leaves
  offseason events out; `all` includes them. The other routes take none,
  because their numbers come from one event or ignore offseason play either
  way.
- `getEventSim` answers `null` before the engine has simulated an event and
  again once the season is over: a simulation is held only while its event is
  live.

## Ratings

`xp` is match13's expected points added: the number that plays the part EPA
plays elsewhere. Every rating model also reports the ratings it is compared
against, so `epa` (Statbotics), `opr` and `dpr` (The Blue Alliance) sit beside
it on the same row and you can show both without a second API.

Across a season, compare teams on `normXp` rather than `xp`. Across an event,
`xpStart` is the rating a team took in and `xpEnd` the rating it took out.

## Errors and retries

`Match13ApiException` exposes `isUnauthorized` and `isRateLimited` alongside
the status code. A 429 and a 5xx are retried, a 429 waiting exactly the
`retryAfter` the API asks for rather than guessing shorter; every other non-2xx
throws on the first response, since resending a request the API rejected on its
merits only spends more of the allowance. Pass `maxAttempts` to change how many
tries a request gets, and `sleep` to make the waits instant in a test.

## Verification status

The fixtures under `test/fixtures/` are bodies captured off the live API, and
the tests pin real values out of them rather than asserting `isNotNull`. All
nine routes were run end to end through this client against the live API on
2026-09-17, every one answering 200 and decoding. The `curl` that produced each
fixture is recorded in the test file; four of them were trimmed to a few rows
to keep the files small, and every row that remains is verbatim.

## License

AGPL-3.0. See [LICENSE](LICENSE).
