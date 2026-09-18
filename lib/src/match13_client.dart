import 'dart:convert';

import 'package:http/http.dart' as http;

import 'match13_models.dart';

/// An error the match13 API reported, in the RFC 9457 `application/problem+json`
/// shape it answers with.
class Match13ApiException implements Exception {
  Match13ApiException({
    required this.statusCode,
    required this.title,
    required this.detail,
    this.type,
    this.limit,
    this.retryAfter,
  });

  /// Builds the exception from a problem+json body, falling back to the status
  /// line when the body is missing or is not the shape the API documents.
  factory Match13ApiException.fromResponse(http.Response response) {
    Map<String, dynamic>? problem;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) problem = decoded.cast<String, dynamic>();
    } on FormatException {
      problem = null;
    }
    final seconds = (problem?['retryAfter'] as num?)?.toInt();
    return Match13ApiException(
      statusCode: response.statusCode,
      title: problem?['title'] as String? ?? 'HTTP ${response.statusCode}',
      detail: problem?['detail'] as String? ?? response.body,
      type: problem?['type'] as String?,
      limit: problem?['limit'] as String?,
      retryAfter: seconds == null ? null : Duration(seconds: seconds),
    );
  }

  final int statusCode;

  /// The short name of the problem, for example `Rate limited`.
  final String title;

  /// What went wrong on this request, for example which value is out of range.
  final String detail;

  /// A link into https://match13.com/docs/api explaining the problem.
  final String? type;

  /// Which window the account spent, on a 429: `minute`, `hour` or `week`.
  final String? limit;

  /// How long to wait before sending the request again, on a 429.
  final Duration? retryAfter;

  /// The key is missing, unknown or revoked.
  bool get isUnauthorized => statusCode == 401;

  /// The account spent one of its rate limit windows.
  bool get isRateLimited => statusCode == 429;

  @override
  String toString() => 'Match13ApiException($statusCode $title): $detail';
}

/// Thin client for the match13 read API.
///
/// Every route needs an account key, made on
/// https://www.match13.com/account and sent as `Authorization: Bearer
/// m13_live_...`. All the keys of one account share one allowance: 60
/// requests a minute, 1000 an hour and 30000 a week, with a 304 and an error
/// counting against it like anything else. Omit [apiKey] (or pass an empty
/// string) when the key is not this client's to hold, for example a proxy
/// that adds it server-side; no `Authorization` header is sent in that case.
///
/// **The API sends no CORS headers**, so this client cannot reach it
/// directly from a Flutter web build. Call it from iOS, Android, desktop or
/// a server, or point [baseUrl] at a proxy that adds CORS headers and the
/// key.
///
/// See https://match13.com/docs/api for the endpoint documentation.
class Match13Client {
  Match13Client({
    String? apiKey,
    String baseUrl = defaultBaseUrl,
    http.Client? httpClient,
    int maxAttempts = 3,
    Future<void> Function(Duration)? sleep,
  }) : _apiKey = apiKey,
       _baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _httpClient = httpClient ?? http.Client(),
       _maxAttempts = maxAttempts < 1 ? 1 : maxAttempts,
       _sleep = sleep ?? Future<void>.delayed;

  /// The match13 API's own host. The default for [baseUrl], and the right
  /// value everywhere except behind a proxy that holds the key server-side
  /// (for example a Flutter web build, which cannot send the key itself
  /// because the API sends no CORS headers).
  static const String defaultBaseUrl = 'https://actions.match13.com';

  final String? _apiKey;
  final String _baseUrl;
  final http.Client _httpClient;

  /// How many times a single request is attempted before giving up. A 429 and
  /// a 5xx are retried; every other non-2xx is thrown straight away, because
  /// resending a request the API has already rejected on its merits only
  /// spends more of the account's allowance.
  final int _maxAttempts;
  final Future<void> Function(Duration) _sleep;

  /// `GET /v1/teams/{team}/years/{year}` -- one team's season, or null when
  /// the team did not play that season.
  Future<Match13TeamSeason?> getTeamSeason(
    int team,
    int year, {
    Match13Scope? scope,
  }) async {
    final body = await _get('/v1/teams/$team/years/$year', scope: scope);
    return body == null ? null : Match13TeamSeason.fromJson(_object(body));
  }

  /// `GET /v1/teams/{team}/years/{year}/events` -- every event the team
  /// played that season, oldest first, or null when it played none.
  Future<Match13TeamEvents?> getTeamEvents(
    int team,
    int year, {
    Match13Scope? scope,
  }) async {
    final body = await _get('/v1/teams/$team/years/$year/events', scope: scope);
    return body == null ? null : Match13TeamEvents.fromJson(_object(body));
  }

  /// `GET /v1/events/{eventKey}/teams` -- every team that played the event,
  /// or null when match13 carries no such event.
  ///
  /// The rows are not in rank order. A team's rating at an event comes from
  /// that event alone, so this route takes no scope.
  Future<Match13EventTeams?> getEventTeams(String eventKey) async {
    final body = await _get('/v1/events/$eventKey/teams');
    return body == null ? null : Match13EventTeams.fromJson(_object(body));
  }

  /// `GET /v1/events/{eventKey}/matches` -- every match of the event with a
  /// forecast for each, or null when match13 carries no such event.
  Future<Match13EventMatches?> getEventMatches(
    String eventKey, {
    Match13Scope? scope,
  }) async {
    final body = await _get('/v1/events/$eventKey/matches', scope: scope);
    return body == null ? null : Match13EventMatches.fromJson(_object(body));
  }

  /// `GET /v1/matches/{matchKey}` -- one match with its forecast, or null
  /// when match13 carries no such match.
  Future<Match13Match?> getMatch(String matchKey, {Match13Scope? scope}) async {
    final body = await _get('/v1/matches/$matchKey', scope: scope);
    return body == null ? null : Match13Match.fromJson(_object(body));
  }

  /// `GET /v1/events/{eventKey}/sim` -- how match13 expects the event to
  /// finish, or null when it holds no simulation for it.
  ///
  /// A simulation is held only while its event is live, so null is the normal
  /// answer before the engine has simulated the event and again once the
  /// season is over.
  Future<Match13EventSim?> getEventSim(String eventKey) async {
    final body = await _get('/v1/events/$eventKey/sim');
    return body == null ? null : Match13EventSim.fromJson(_object(body));
  }

  /// `GET /v1/years/{year}/teams` -- one page of the season's teams, best
  /// first, or null when match13 carries no such season.
  ///
  /// Pages start at 1 and [Match13YearTeams.nextPage] is null on the last
  /// one. The rows carry no `components`; read a team on its own with
  /// [getTeamSeason] for those.
  Future<Match13YearTeams?> getYearTeams(
    int year, {
    int? page,
    int? limit,
    Match13Scope? scope,
  }) async {
    final body = await _get(
      '/v1/years/$year/teams',
      scope: scope,
      queryParameters: <String, String>{
        if (page != null) 'page': page.toString(),
        if (limit != null) 'limit': limit.toString(),
      },
    );
    return body == null ? null : Match13YearTeams.fromJson(_object(body));
  }

  /// `GET /v1/districts/{code}/{year}/teams` -- a district's standings in
  /// rank order, or null when match13 carries no such district that season.
  ///
  /// [code] is the district code as The Blue Alliance writes it: `fim`, `ne`,
  /// `pnw`. District points ignore offseason play, so this route takes no
  /// scope.
  Future<Match13DistrictTeams?> getDistrictTeams(String code, int year) async {
    final body = await _get('/v1/districts/$code/$year/teams');
    return body == null ? null : Match13DistrictTeams.fromJson(_object(body));
  }

  /// `GET /v1/regionals/{year}/teams` -- the regional pool's standings in
  /// rank order, or null when match13 carries no pool that season.
  ///
  /// Pool points ignore offseason play, so this route takes no scope.
  Future<Match13RegionalTeams?> getRegionalTeams(int year) async {
    final body = await _get('/v1/regionals/$year/teams');
    return body == null ? null : Match13RegionalTeams.fromJson(_object(body));
  }

  /// Releases the underlying HTTP client. Call it when you are done with the
  /// client.
  void close() => _httpClient.close();

  Map<String, dynamic> _object(String body) =>
      (jsonDecode(body) as Map).cast<String, dynamic>();

  /// Sends one GET, retrying a 429 or a 5xx. Answers null on 404, the body on
  /// 2xx, and throws [Match13ApiException] on anything else.
  Future<String?> _get(
    String path, {
    Match13Scope? scope,
    Map<String, String>? queryParameters,
  }) async {
    final query = <String, String>{
      if (scope != null) 'scope': scope.wireName,
      ...?queryParameters,
    };
    final uri = Uri.parse('$_baseUrl$path')
        .replace(queryParameters: query.isEmpty ? null : query);

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      http.Response response;
      try {
        response = await _httpClient.get(
          uri,
          headers: <String, String>{
            if (_apiKey != null && _apiKey.isNotEmpty)
              'Authorization': 'Bearer $_apiKey',
            'Accept': 'application/json',
          },
        );
      } on Exception {
        // A dropped connection is as transient as a 500, and retrying it is
        // what makes an event-day refresh survive a flaky venue network.
        if (attempt == _maxAttempts) rethrow;
        await _sleep(_backoff(attempt));
        continue;
      }

      if (response.statusCode == 404) return null;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.body;
      }

      final failure = Match13ApiException.fromResponse(response);
      final transient =
          response.statusCode == 429 || response.statusCode >= 500;
      if (!transient || attempt == _maxAttempts) throw failure;
      // The API says how long to wait on a 429. Guessing shorter than that
      // just spends another request against the window that is already out.
      await _sleep(failure.retryAfter ?? _backoff(attempt));
    }

    // Unreachable: the last attempt either returns or throws above. Dart
    // still needs a terminal statement here.
    throw StateError('no attempt was made for $uri');
  }

  Duration _backoff(int attempt) => Duration(milliseconds: 200 * attempt);
}
