import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:match13_client/match13_client.dart';
import 'package:test/test.dart';

/// The fixtures under `test/fixtures/` are the response examples the API
/// publishes for each route at https://match13.com/docs/api, one file per
/// route, saved verbatim. They are the server's own examples rather than a
/// body captured off a live call, because the API answers 401 without an
/// account key and this repository holds none. Replace a fixture with the
/// real thing once a key exists:
///
///   curl -H "Authorization: Bearer $MATCH13_KEY" \
///     https://actions.match13.com/v1/events/2025casj/teams \
///     > test/fixtures/event_teams.json
///
/// Until that has happened, treat every model here as matching the published
/// schema and unproven against the live API.
String _fixture(String name) =>
    File('test/fixtures/$name.json').readAsStringSync();

http.Response _ok(String body) => http.Response(
      body,
      200,
      headers: const <String, String>{'content-type': 'application/json'},
    );

http.Response _problem(
  int status,
  Map<String, dynamic> body, {
  Map<String, String> headers = const <String, String>{},
}) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: <String, String>{
        'content-type': 'application/problem+json',
        ...headers,
      },
    );

Match13Client _clientFor(
  MockClient mockClient, {
  int maxAttempts = 3,
  List<Duration>? slept,
}) =>
    Match13Client(
      apiKey: 'm13_live_test',
      httpClient: mockClient,
      maxAttempts: maxAttempts,
      sleep: (duration) async => slept?.add(duration),
    );

void main() {
  group('requests', () {
    test('sends the key as a bearer token', () async {
      late http.Request seen;
      final client = _clientFor(
        MockClient((request) async {
          seen = request;
          return _ok(_fixture('team_season'));
        }),
      );

      await client.getTeamSeason(581, 2025);

      expect(seen.headers['Authorization'], 'Bearer m13_live_test');
      expect(
        seen.url.toString(),
        'https://actions.match13.com/v1/teams/581/years/2025',
      );
    });

    test('sends scope only when one is given', () async {
      final urls = <String>[];
      final client = _clientFor(
        MockClient((request) async {
          urls.add(request.url.toString());
          return _ok(_fixture('match'));
        }),
      );

      await client.getMatch('2025casj_qm42');
      await client.getMatch('2025casj_qm42', scope: Match13Scope.all);

      expect(urls[0], 'https://actions.match13.com/v1/matches/2025casj_qm42');
      expect(urls[1], endsWith('/v1/matches/2025casj_qm42?scope=all'));
    });

    test('pages the season team list', () async {
      late Uri seen;
      final client = _clientFor(
        MockClient((request) async {
          seen = request.url;
          return _ok(_fixture('year_teams'));
        }),
      );

      await client.getYearTeams(2025, page: 2, limit: 500);

      expect(seen.path, '/v1/years/2025/teams');
      expect(seen.queryParameters, <String, String>{
        'page': '2',
        'limit': '500',
      });
    });
  });

  group('parsing', () {
    test('getTeamSeason reads the season rating and its parts', () async {
      final client = _clientFor(
        MockClient((_) async => _ok(_fixture('team_season'))),
      );

      final season = await client.getTeamSeason(581, 2025);

      expect(season!.teamNumber, 581);
      expect(season.year, 2025);
      expect(season.xp, closeTo(81.886, 1e-9));
      expect(season.normXp, closeTo(1915.9457, 1e-9));
      expect(season.rank, 55);
      expect(season.percentile, closeTo(98.535, 1e-9));
      expect(season.xAuto, closeTo(18.9743, 1e-9));
      expect(season.xTele, closeTo(54.4374, 1e-9));
      expect(season.xEnd, closeTo(8.4743, 1e-9));
      expect(season.xRp1, closeTo(0.642408, 1e-9));
      expect(season.epa, closeTo(81.0364, 1e-9));
      expect(season.opr, closeTo(86.6324, 1e-9));
      expect(season.dpr, closeTo(72.4292, 1e-9));
      expect(season.components, <String, double>{
        'barge': 8.3237,
        'coral': 15.1417,
      });
    });

    test('getTeamEvents reads one row per event, oldest first', () async {
      final client = _clientFor(
        MockClient((_) async => _ok(_fixture('team_events'))),
      );

      final history = await client.getTeamEvents(581, 2025);

      expect(history!.teamNumber, 581);
      expect(history.year, 2025);
      expect(
        history.events.map((event) => event.eventKey),
        <String>['2025camb', '2025casj', '2025joh'],
      );
      final first = history.events.first;
      expect(first.teamNumber, isNull, reason: 'the row names the event');
      expect(first.xpStart, closeTo(69.9257, 1e-9));
      expect(first.xpEnd, closeTo(81.9525, 1e-9));
      expect(first.xpMean, closeTo(80.629, 1e-9));
      expect(first.xpMax, closeTo(84.9737, 1e-9));
      expect(first.sos, isNull);
      expect(first.districtPoints, isNull);
      expect(first.regionalPoints, isNull);
    });

    test('getEventTeams reads one row per team, unranked', () async {
      final client = _clientFor(
        MockClient((_) async => _ok(_fixture('event_teams'))),
      );

      final event = await client.getEventTeams('2025casj');

      expect(event!.eventKey, '2025casj');
      expect(event.year, 2025);
      expect(event.teams, hasLength(3));
      final first = event.teams.first;
      expect(first.teamNumber, 1323);
      expect(first.eventKey, isNull, reason: 'the row names the team');
      expect(first.xpEnd, closeTo(123.8269, 1e-9));
      expect(first.components['coral'], closeTo(17.0423, 1e-9));
      expect(
        event.teams.map((team) => team.teamNumber),
        <int>[1323, 8793, 2367],
        reason: 'the API does not send these in rank order',
      );
    });

    test('getEventMatches reads a forecast per match', () async {
      final client = _clientFor(
        MockClient((_) async => _ok(_fixture('event_matches'))),
      );

      final event = await client.getEventMatches('2025casj');

      expect(event!.eventKey, '2025casj');
      expect(event.year, 2025);
      expect(
        event.matches.map((match) => match.key),
        <String>['2025casj_qm42', '2025casj_f1m1'],
      );
      final prediction = event.matches.first.prediction;
      expect(prediction.winProb, closeTo(0.981692, 1e-9));
      expect(prediction.redScore, closeTo(100.7128, 1e-9));
      expect(prediction.blueScore, closeTo(36.885, 1e-9));
      expect(prediction.redRp1, closeTo(0.841082, 1e-9));
      expect(prediction.blueRp2, closeTo(0.004122, 1e-9));
    });

    test('getMatch keys the teams by team number', () async {
      final client =
          _clientFor(MockClient((_) async => _ok(_fixture('match'))));

      final match = await client.getMatch('2025casj_qm42');

      expect(match!.key, '2025casj_qm42');
      expect(match.bye, isNull);
      expect(
        match.teams.keys.toList()..sort(),
        <int>[751, 3045, 4990, 5027, 8793, 10059],
      );
      final team = match.teams[3045]!;
      expect(team.xpPre, closeTo(70.7679, 1e-9));
      expect(team.xpPost, closeTo(69.8956, 1e-9));
      expect(team.xAutoPre, closeTo(16.8679, 1e-9));
      expect(team.xEndPost, closeTo(2.8656, 1e-9));
    });

    test('an unplayed match has no post-match ratings', () async {
      final client = _clientFor(
        MockClient(
          (_) async => _ok(
            jsonEncode(<String, dynamic>{
              'key': '2026casj_qm1',
              'pred': <String, dynamic>{
                'winProb': 0.5,
                'redScore': 50,
                'blueScore': 50,
                'redVar': 100,
                'blueVar': 100,
                'redRp1': null,
                'redRp2': null,
                'redRp3': null,
                'blueRp1': null,
                'blueRp2': null,
                'blueRp3': null,
              },
              'teams': <String, dynamic>{
                '3847': <String, dynamic>{
                  'xpPre': 42.5,
                  'xpPost': null,
                  'xAutoPre': 10.0,
                  'xTelePre': 25.0,
                  'xEndPre': 7.5,
                  'xAutoPost': null,
                  'xTelePost': null,
                  'xEndPost': null,
                },
              },
            }),
          ),
        ),
      );

      final match = await client.getMatch('2026casj_qm1');

      final team = match!.teams[3847]!;
      expect(team.xpPre, 42.5);
      expect(team.xpPost, isNull);
      expect(team.xAutoPost, isNull);
      expect(match.prediction.redRp1, isNull);
    });

    test('getEventSim reads the run and its per-team ranks', () async {
      final client = _clientFor(
        MockClient((_) async => _ok(_fixture('event_sim'))),
      );

      final sim = await client.getEventSim('2026arc');

      expect(sim!.eventKey, '2026arc');
      expect(sim.year, 2026);
      expect(sim.iterations, 25000);
      expect(sim.simmedAt.millisecondsSinceEpoch, 1788043031454);
      expect(sim.simmedAt.isUtc, isTrue);
      final first = sim.teams.first;
      expect(first.teamNumber, 27);
      expect(first.meanRank, 7);
      expect(first.meanRps, 40);
      expect(first.p5, 7);
      expect(first.p95, 7);
    });

    test('getYearTeams reads the page and its rows', () async {
      final client = _clientFor(
        MockClient((_) async => _ok(_fixture('year_teams'))),
      );

      final page = await client.getYearTeams(2025);

      expect(page!.year, 2025);
      expect(page.page, 1);
      expect(page.limit, 3);
      expect(page.total, 3687);
      expect(page.nextPage, 2);
      final first = page.teams.first;
      expect(first.teamNumber, 2056);
      expect(first.rank, 1);
      expect(first.xp, closeTo(110.6698, 1e-9));
      expect(
        first.components,
        isEmpty,
        reason: 'a year-teams row carries no components',
      );
    });

    test('getDistrictTeams reads the pools and the seat forecast', () async {
      final client = _clientFor(
        MockClient((_) async => _ok(_fixture('district_teams'))),
      );

      final district = await client.getDistrictTeams('fim', 2025);

      expect(district!.code, 'fim');
      expect(district.districtKey, '2025fim');
      expect(district.year, 2025);
      expect(district.source, Match13StandingSource.engine);
      expect(district.capacity, 160);
      expect(district.cmpSlots, 83);
      expect(district.cmpPrequalSlots, 2);
      expect(district.cmpCutline!.q50, 190);
      expect(district.pools, hasLength(1));
      expect(district.pools.first.name, 'fim');
      expect(district.pools.first.autos, 5);
      expect(district.pools.first.seatsByPoints, 155);
      expect(district.pools.first.cutline!.q50, 70.5);

      final leader = district.teams.first;
      expect(leader.teamNumber, 27);
      expect(leader.rank, 1);
      expect(leader.pool, 'fim');
      expect(leader.total, 359);
      expect(leader.pCmp, 1);
      expect(leader.dcmpStatus, Match13SeatStatus.qualified);
      expect(leader.cmpStatus, Match13SeatStatus.locked);
      expect(leader.events, hasLength(3));
      expect(leader.events.first.eventKey, '2025miket');
      expect(leader.events.first.counted, isTrue);
      expect(
        leader.events.first.rookie,
        isNull,
        reason: 'a district row carries the rookie bonus on the team',
      );

      expect(
        district.teams.last.cmpStatus,
        Match13SeatStatus.lockedOut,
        reason: 'the wire spells this one with an underscore',
      );
      expect(district.teams[1].cmpStatus, Match13SeatStatus.inRange);
    });

    test('getRegionalTeams reads the pool rules and the seat count', () async {
      final client = _clientFor(
        MockClient((_) async => _ok(_fixture('regional_teams'))),
      );

      final pool = await client.getRegionalTeams(2026);

      expect(pool!.year, 2026);
      expect(pool.source, Match13StandingSource.engine);
      expect(pool.rules!.regionalSeats, 250);
      expect(pool.rules!.direct, 'top_by_points');
      expect(pool.rules!.usDirect, 3);
      expect(pool.rules!.internationalDirect, 4);
      expect(pool.rules!.provisional, isFalse);
      expect(pool.seats.direct, 184);
      expect(pool.seats.directTotal, 184);
      expect(pool.seats.pool, 77);
      expect(pool.seats.prequal, 5);
      expect(pool.seats.declined, 0);
      expect(pool.regionalsTotal, 12);
      expect(pool.regionalsComplete, 12);
      expect(pool.poolCutline!.q50, 48);

      final leader = pool.teams.first;
      expect(leader.teamNumber, 4403);
      expect(leader.rank, 1);
      expect(leader.total, 195);
      expect(leader.projected, isNull);
      expect(leader.status, Match13SeatStatus.qualified);
      expect(leader.via, 'Top 4 at 2026mxto');
      expect(leader.events.first.rookie, 0);

      expect(
        pool.teams[1].projected,
        79,
        reason: 'a team with one regional carries a projected second',
      );
      expect(pool.teams.last.status, Match13SeatStatus.outOfRange);
      expect(pool.teams.last.via, isNull);
    });

    test('a tba-sourced standing has no forecast', () async {
      final client = _clientFor(
        MockClient(
          (_) async => _ok(
            jsonEncode(<String, dynamic>{
              'code': 'ne',
              'districtKey': '2026ne',
              'year': 2026,
              'source': 'tba',
              'capacity': 100,
              'cmpSlots': 40,
              'cmpPrequalSlots': 0,
              'pools': <dynamic>[],
              'cmpCutline': null,
              'teams': <dynamic>[
                <String, dynamic>{
                  'teamNumber': 3847,
                  'rank': 12,
                  'pool': null,
                  'total': 48,
                  'rookieBonus': 0,
                  'adjustments': 0,
                  'events': <dynamic>[],
                  'mean': null,
                  'q10': null,
                  'q50': null,
                  'q90': null,
                  'pDcmp': null,
                  'pCmp': null,
                  'dcmpStatus': null,
                  'cmpStatus': null,
                },
              ],
            }),
          ),
        ),
      );

      final district = await client.getDistrictTeams('ne', 2026);

      expect(district!.source, Match13StandingSource.tba);
      expect(district.cmpCutline, isNull);
      final team = district.teams.single;
      expect(team.rank, 12);
      expect(team.mean, isNull);
      expect(team.pCmp, isNull);
      expect(team.dcmpStatus, isNull);
      expect(team.cmpStatus, isNull);
    });
  });

  group('errors', () {
    test('404 answers null rather than throwing', () async {
      final client = _clientFor(
        MockClient(
          (_) async => _problem(404, <String, dynamic>{
            'type': 'https://match13.com/docs/api#not-found',
            'title': 'Not found',
            'status': 404,
            'detail': 'No resource at this path.',
          }),
        ),
      );

      expect(await client.getEventSim('2026casj'), isNull);
      expect(await client.getTeamSeason(3847, 1999), isNull);
    });

    // The one fixture captured off the live API rather than off the docs: an
    // unauthenticated call is the only one this repository can make.
    //   curl https://actions.match13.com/v1/events/2025casj/teams \
    //     > test/fixtures/unauthorized.json
    test('401 throws with the problem body read out', () async {
      final client = _clientFor(
        MockClient(
          (_) async => http.Response(
            _fixture('unauthorized'),
            401,
            headers: const <String, String>{
              'content-type': 'application/problem+json',
            },
          ),
        ),
      );

      await expectLater(
        client.getEventTeams('2025casj'),
        throwsA(
          isA<Match13ApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.isUnauthorized, 'isUnauthorized', isTrue)
              .having((e) => e.title, 'title', 'Unauthorized')
              .having(
                (e) => e.type,
                'type',
                'https://match13.com/docs/api#unauthorized',
              )
              .having((e) => e.detail, 'detail', contains('m13_live_')),
        ),
      );
    });

    test('422 is not retried, because the request is the problem', () async {
      var calls = 0;
      final client = _clientFor(
        MockClient((_) async {
          calls++;
          return _problem(422, <String, dynamic>{
            'title': 'Invalid argument',
            'status': 422,
            'detail': 'scope must be "season" or "all", got "everything"',
          });
        }),
      );

      await expectLater(
        client.getYearTeams(2025),
        throwsA(isA<Match13ApiException>()),
      );
      expect(calls, 1);
    });

    test('429 waits the Retry-After the API gives, then succeeds', () async {
      final slept = <Duration>[];
      var calls = 0;
      final client = _clientFor(
        MockClient((_) async {
          calls++;
          if (calls == 1) {
            return _problem(429, <String, dynamic>{
              'title': 'Rate limited',
              'status': 429,
              'detail': 'The minute allowance is spent.',
              'limit': 'minute',
              'retryAfter': 19,
            });
          }
          return _ok(_fixture('team_season'));
        }),
        slept: slept,
      );

      final season = await client.getTeamSeason(581, 2025);

      expect(season!.teamNumber, 581);
      expect(calls, 2);
      expect(slept, <Duration>[const Duration(seconds: 19)]);
    });

    test('a spent allowance throws with the window and the wait', () async {
      final client = _clientFor(
        MockClient(
          (_) async => _problem(429, <String, dynamic>{
            'title': 'Rate limited',
            'status': 429,
            'detail': 'The week allowance is spent.',
            'limit': 'week',
            'retryAfter': 3600,
          }),
        ),
        maxAttempts: 2,
      );

      await expectLater(
        client.getEventTeams('2025casj'),
        throwsA(
          isA<Match13ApiException>()
              .having((e) => e.isRateLimited, 'isRateLimited', isTrue)
              .having((e) => e.limit, 'limit', 'week')
              .having(
                (e) => e.retryAfter,
                'retryAfter',
                const Duration(seconds: 3600),
              ),
        ),
      );
    });

    test('a 500 is retried and the retry is used', () async {
      var calls = 0;
      final client = _clientFor(
        MockClient((_) async {
          calls++;
          if (calls < 3) return http.Response('upstream is down', 500);
          return _ok(_fixture('event_teams'));
        }),
      );

      final event = await client.getEventTeams('2025casj');

      expect(event!.teams, hasLength(3));
      expect(calls, 3);
    });

    test('a 500 with no problem body still names the status', () async {
      final client = _clientFor(
        MockClient((_) async => http.Response('', 500)),
        maxAttempts: 1,
      );

      await expectLater(
        client.getEventTeams('2025casj'),
        throwsA(
          isA<Match13ApiException>()
              .having((e) => e.title, 'title', 'HTTP 500'),
        ),
      );
    });

    test('a dropped connection is retried', () async {
      var calls = 0;
      final client = _clientFor(
        MockClient((_) async {
          calls++;
          if (calls == 1) throw const SocketException('connection reset');
          return _ok(_fixture('team_season'));
        }),
      );

      expect((await client.getTeamSeason(581, 2025))!.teamNumber, 581);
      expect(calls, 2);
    });
  });
}
