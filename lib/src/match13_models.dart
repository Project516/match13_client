// Models for the match13 read API. Field names follow the wire exactly, so a
// reader can check a model against https://match13.com/docs/api without a
// translation table.
//
// Every rating field the API declares as `number | null` is a `double?` here.
// A null means the model has nothing to say yet, not zero: a match that has
// not been played has null `*Post` values, and a season that publishes no
// gamepiece estimates gives an empty `components`.

double? _numOrNull(Object? value) => (value as num?)?.toDouble();

double _num(Object? value) => (value as num?)?.toDouble() ?? 0;

int _int(Object? value) => (value as num?)?.toInt() ?? 0;

bool _bool(Object? value) => value as bool? ?? false;

Map<String, double> _components(Object? value) {
  final map = (value as Map?)?.cast<String, dynamic>();
  if (map == null) return const <String, double>{};
  return map.map((key, value) => MapEntry(key, _num(value)));
}

List<T> _list<T>(Object? value, T Function(Map<String, dynamic>) parse) {
  final list = value as List<dynamic>?;
  if (list == null) return <T>[];
  return list
      .map((row) => parse((row as Map).cast<String, dynamic>()))
      .toList(growable: false);
}

/// Which model run the numbers come from.
///
/// `season` leaves offseason events out and is what the API uses when a
/// request names no scope. `all` includes them. The routes that take no scope
/// ignore it.
enum Match13Scope {
  season('season'),
  all('all');

  const Match13Scope(this.wireName);

  final String wireName;
}

/// One team's season: its xP rating, the parts that rating breaks into, and
/// the ratings match13 compares itself against.
///
/// `GET /v1/teams/{team}/years/{year}`, and one row of
/// `GET /v1/years/{year}/teams`. The year-teams rows carry no [components],
/// so that map is empty there; read the team on its own to get the gamepiece
/// estimates.
class Match13TeamSeason {
  Match13TeamSeason({
    required this.teamNumber,
    required this.year,
    required this.xp,
    required this.normXp,
    required this.xVar,
    required this.xAuto,
    required this.xTele,
    required this.xEnd,
    required this.xRp1,
    required this.xRp2,
    required this.xRp3,
    required this.rank,
    required this.percentile,
    required this.epa,
    required this.opr,
    required this.dpr,
    required this.components,
  });

  factory Match13TeamSeason.fromJson(Map<String, dynamic> json) {
    return Match13TeamSeason(
      teamNumber: _int(json['teamNumber']),
      year: _int(json['year']),
      xp: _num(json['xp']),
      normXp: _num(json['normXp']),
      xVar: _num(json['xVar']),
      xAuto: _numOrNull(json['xAuto']),
      xTele: _numOrNull(json['xTele']),
      xEnd: _numOrNull(json['xEnd']),
      xRp1: _numOrNull(json['xRp1']),
      xRp2: _numOrNull(json['xRp2']),
      xRp3: _numOrNull(json['xRp3']),
      rank: _int(json['rank']),
      percentile: _num(json['percentile']),
      epa: _numOrNull(json['epa']),
      opr: _numOrNull(json['opr']),
      dpr: _numOrNull(json['dpr']),
      components: _components(json['components']),
    );
  }

  final int teamNumber;
  final int year;

  /// The team's xP rating for the season: match13's expected contribution to
  /// an alliance's score, the number that plays the part EPA plays elsewhere.
  final double xp;

  /// [xp] put on a fixed scale so seasons can be compared to each other.
  final double normXp;

  final double xVar;
  final double? xAuto;
  final double? xTele;
  final double? xEnd;

  /// The team's chance at each of the season's three ranking points.
  final double? xRp1;
  final double? xRp2;
  final double? xRp3;

  /// The team's rank among the season's teams, 1 being the best.
  final int rank;

  final double percentile;

  /// Statbotics EPA, TBA OPR and TBA DPR for the same team and season, so a
  /// caller can show match13's number beside the ones it is replacing.
  final double? epa;
  final double? opr;
  final double? dpr;

  /// The season's gamepiece estimates, keyed by the season's own names
  /// (`coral`, `barge`, and so on). Empty for a season that publishes none,
  /// and empty on a `GET /v1/years/{year}/teams` row.
  final Map<String, double> components;
}

/// A team's district points at one event.
class Match13DistrictPoints {
  Match13DistrictPoints({
    required this.qual,
    required this.elim,
    required this.alliance,
    required this.award,
    required this.total,
    required this.counted,
    required this.isFinal,
    required this.tier,
  });

  factory Match13DistrictPoints.fromJson(Map<String, dynamic> json) {
    return Match13DistrictPoints(
      qual: _num(json['qual']),
      elim: _num(json['elim']),
      alliance: _num(json['alliance']),
      award: _num(json['award']),
      total: _num(json['total']),
      counted: _bool(json['counted']),
      isFinal: _bool(json['final']),
      tier: json['tier'] as String? ?? '',
    );
  }

  final double qual;
  final double elim;
  final double alliance;
  final double award;
  final double total;

  /// False when the event's points do not score toward the district total.
  final bool counted;

  /// The wire field is `final`, which Dart reserves.
  final bool isFinal;

  final String tier;
}

/// A team's regional pool points at one event.
class Match13RegionalPoints {
  Match13RegionalPoints({
    required this.qual,
    required this.elim,
    required this.alliance,
    required this.award,
    required this.rookie,
    required this.counted,
    required this.isFinal,
  });

  factory Match13RegionalPoints.fromJson(Map<String, dynamic> json) {
    return Match13RegionalPoints(
      qual: _num(json['qual']),
      elim: _num(json['elim']),
      alliance: _num(json['alliance']),
      award: _num(json['award']),
      rookie: _num(json['rookie']),
      counted: _bool(json['counted']),
      isFinal: _bool(json['final']),
    );
  }

  final double qual;
  final double elim;
  final double alliance;
  final double award;
  final double rookie;

  /// False when the regional's points do not count toward the pool total.
  final bool counted;

  /// The wire field is `final`, which Dart reserves.
  final bool isFinal;
}

/// What one team did at one event: the rating it took in, the rating it took
/// out, and the mean and maximum in between.
///
/// The same shape answers both directions. A row of
/// `GET /v1/teams/{team}/years/{year}/events` names the event and leaves
/// [teamNumber] null; a row of `GET /v1/events/{eventKey}/teams` names the
/// team and leaves [eventKey] null.
class Match13TeamEvent {
  Match13TeamEvent({
    required this.eventKey,
    required this.teamNumber,
    required this.xpStart,
    required this.xpEnd,
    required this.xpMean,
    required this.xpMax,
    required this.xVar,
    required this.xAuto,
    required this.xTele,
    required this.xEnd,
    required this.xRp1,
    required this.xRp2,
    required this.xRp3,
    required this.sos,
    required this.epa,
    required this.opr,
    required this.dpr,
    required this.components,
    required this.districtPoints,
    required this.regionalPoints,
  });

  factory Match13TeamEvent.fromJson(Map<String, dynamic> json) {
    final district = (json['districtPoints'] as Map?)?.cast<String, dynamic>();
    final regional = (json['regionalPoints'] as Map?)?.cast<String, dynamic>();
    return Match13TeamEvent(
      eventKey: json['eventKey'] as String?,
      teamNumber: (json['teamNumber'] as num?)?.toInt(),
      xpStart: _num(json['xpStart']),
      xpEnd: _num(json['xpEnd']),
      xpMean: _numOrNull(json['xpMean']),
      xpMax: _numOrNull(json['xpMax']),
      xVar: _num(json['xVar']),
      xAuto: _numOrNull(json['xAuto']),
      xTele: _numOrNull(json['xTele']),
      xEnd: _numOrNull(json['xEnd']),
      xRp1: _numOrNull(json['xRp1']),
      xRp2: _numOrNull(json['xRp2']),
      xRp3: _numOrNull(json['xRp3']),
      sos: _numOrNull(json['sos']),
      epa: _numOrNull(json['epa']),
      opr: _numOrNull(json['opr']),
      dpr: _numOrNull(json['dpr']),
      components: _components(json['components']),
      districtPoints:
          district == null ? null : Match13DistrictPoints.fromJson(district),
      regionalPoints:
          regional == null ? null : Match13RegionalPoints.fromJson(regional),
    );
  }

  /// Set on a team-events row, null on an event-teams row.
  final String? eventKey;

  /// Set on an event-teams row, null on a team-events row.
  final int? teamNumber;

  /// The rating the team took into the event.
  final double xpStart;

  /// The rating the team took out of the event. This is the one to rank an
  /// event's teams by.
  final double xpEnd;

  final double? xpMean;
  final double? xpMax;
  final double xVar;
  final double? xAuto;
  final double? xTele;
  final double? xEnd;
  final double? xRp1;
  final double? xRp2;
  final double? xRp3;

  /// Strength of schedule.
  final double? sos;

  /// Statbotics EPA, TBA OPR and TBA DPR for the same team at the same event.
  final double? epa;
  final double? opr;
  final double? dpr;

  final Map<String, double> components;

  /// Null at an event that pays no district points.
  final Match13DistrictPoints? districtPoints;

  /// Null at an event that pays no regional pool points.
  final Match13RegionalPoints? regionalPoints;
}

/// Every event one team played in one season, oldest first.
class Match13TeamEvents {
  Match13TeamEvents({
    required this.teamNumber,
    required this.year,
    required this.events,
  });

  factory Match13TeamEvents.fromJson(Map<String, dynamic> json) {
    return Match13TeamEvents(
      teamNumber: _int(json['teamNumber']),
      year: _int(json['year']),
      events: _list(json['events'], Match13TeamEvent.fromJson),
    );
  }

  final int teamNumber;
  final int year;
  final List<Match13TeamEvent> events;
}

/// Every team that played one event.
class Match13EventTeams {
  Match13EventTeams({
    required this.eventKey,
    required this.year,
    required this.teams,
  });

  factory Match13EventTeams.fromJson(Map<String, dynamic> json) {
    return Match13EventTeams(
      eventKey: json['eventKey'] as String? ?? '',
      year: _int(json['year']),
      teams: _list(json['teams'], Match13TeamEvent.fromJson),
    );
  }

  final String eventKey;
  final int year;

  /// In the order the API sent them, which is not rank order. Sort by
  /// [Match13TeamEvent.xpEnd] descending to rank them.
  final List<Match13TeamEvent> teams;
}

/// match13's forecast for one match.
class Match13Prediction {
  Match13Prediction({
    required this.winProb,
    required this.redScore,
    required this.blueScore,
    required this.redVar,
    required this.blueVar,
    required this.redRp1,
    required this.redRp2,
    required this.redRp3,
    required this.blueRp1,
    required this.blueRp2,
    required this.blueRp3,
  });

  factory Match13Prediction.fromJson(Map<String, dynamic> json) {
    return Match13Prediction(
      winProb: _num(json['winProb']),
      redScore: _num(json['redScore']),
      blueScore: _num(json['blueScore']),
      redVar: _num(json['redVar']),
      blueVar: _num(json['blueVar']),
      redRp1: _numOrNull(json['redRp1']),
      redRp2: _numOrNull(json['redRp2']),
      redRp3: _numOrNull(json['redRp3']),
      blueRp1: _numOrNull(json['blueRp1']),
      blueRp2: _numOrNull(json['blueRp2']),
      blueRp3: _numOrNull(json['blueRp3']),
    );
  }

  /// The chance that red wins, 0 to 1. Blue's chance is what is left over.
  final double winProb;

  final double redScore;
  final double blueScore;
  final double redVar;
  final double blueVar;

  /// Each alliance's chance at each of the season's three ranking points.
  final double? redRp1;
  final double? redRp2;
  final double? redRp3;
  final double? blueRp1;
  final double? blueRp2;
  final double? blueRp3;
}

/// One team's rating either side of one match.
///
/// Every `*Post` value is null until the match is complete. A team's [xpPre]
/// is its [xpPost] from the match before, and its season starting rating for
/// its first match.
class Match13MatchTeam {
  Match13MatchTeam({
    required this.xpPre,
    required this.xpPost,
    required this.xAutoPre,
    required this.xTelePre,
    required this.xEndPre,
    required this.xAutoPost,
    required this.xTelePost,
    required this.xEndPost,
  });

  factory Match13MatchTeam.fromJson(Map<String, dynamic> json) {
    return Match13MatchTeam(
      xpPre: _numOrNull(json['xpPre']),
      xpPost: _numOrNull(json['xpPost']),
      xAutoPre: _numOrNull(json['xAutoPre']),
      xTelePre: _numOrNull(json['xTelePre']),
      xEndPre: _numOrNull(json['xEndPre']),
      xAutoPost: _numOrNull(json['xAutoPost']),
      xTelePost: _numOrNull(json['xTelePost']),
      xEndPost: _numOrNull(json['xEndPost']),
    );
  }

  final double? xpPre;
  final double? xpPost;
  final double? xAutoPre;
  final double? xTelePre;
  final double? xEndPre;
  final double? xAutoPost;
  final double? xTelePost;
  final double? xEndPost;
}

/// One match, with match13's forecast for it.
///
/// match13 carries ratings, not a schedule: there is no comp level, match
/// number, time, alliance colour or score here. Read those from The Blue
/// Alliance and join on [key].
class Match13Match {
  Match13Match({
    required this.key,
    required this.bye,
    required this.prediction,
    required this.teams,
  });

  factory Match13Match.fromJson(Map<String, dynamic> json) {
    final prediction = (json['pred'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final teams = (json['teams'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return Match13Match(
      key: json['key'] as String? ?? '',
      bye: json['bye'] as bool?,
      prediction: Match13Prediction.fromJson(prediction),
      teams: teams.map(
        (team, row) => MapEntry(
          int.tryParse(team) ?? 0,
          Match13MatchTeam.fromJson((row as Map).cast<String, dynamic>()),
        ),
      ),
    );
  }

  /// The Blue Alliance match key, for example `2025casj_qm42`.
  final String key;

  /// Present only on a playoff bye.
  final bool? bye;

  final Match13Prediction prediction;

  /// Keyed by team number. The wire keys them by a string team number; this
  /// map parses those to ints so a caller can look a team up directly.
  final Map<int, Match13MatchTeam> teams;
}

/// Every match of one event, with a forecast for each.
class Match13EventMatches {
  Match13EventMatches({
    required this.eventKey,
    required this.year,
    required this.matches,
  });

  factory Match13EventMatches.fromJson(Map<String, dynamic> json) {
    return Match13EventMatches(
      eventKey: json['eventKey'] as String? ?? '',
      year: _int(json['year']),
      matches: _list(json['matches'], Match13Match.fromJson),
    );
  }

  final String eventKey;
  final int year;
  final List<Match13Match> matches;
}

/// One team's place in an event simulation.
///
/// Once the qualification matches are all played the rank is settled, so
/// [p5], [p50] and [p95] all read the same number.
class Match13SimTeam {
  Match13SimTeam({
    required this.teamNumber,
    required this.meanRank,
    required this.meanRps,
    required this.p5,
    required this.p50,
    required this.p95,
  });

  factory Match13SimTeam.fromJson(Map<String, dynamic> json) {
    return Match13SimTeam(
      teamNumber: _int(json['teamNumber']),
      meanRank: _num(json['meanRank']),
      meanRps: _num(json['meanRps']),
      p5: _num(json['p5']),
      p50: _num(json['p50']),
      p95: _num(json['p95']),
    );
  }

  final int teamNumber;
  final double meanRank;
  final double meanRps;
  final double p5;
  final double p50;
  final double p95;
}

/// How match13 expects an event to finish.
///
/// Held only while the event is live: the route answers 404 before the engine
/// has simulated the event, and again once the season is over.
class Match13EventSim {
  Match13EventSim({
    required this.eventKey,
    required this.year,
    required this.iterations,
    required this.simmedAt,
    required this.teams,
  });

  factory Match13EventSim.fromJson(Map<String, dynamic> json) {
    return Match13EventSim(
      eventKey: json['eventKey'] as String? ?? '',
      year: _int(json['year']),
      iterations: _int(json['iterations']),
      simmedAt: DateTime.fromMillisecondsSinceEpoch(
        _int(json['simmedAt']),
        isUtc: true,
      ),
      teams: _list(json['teams'], Match13SimTeam.fromJson),
    );
  }

  final String eventKey;
  final int year;

  /// How many times the engine played the event out.
  final int iterations;

  /// When the engine last ran, parsed from the wire's epoch milliseconds.
  final DateTime simmedAt;

  final List<Match13SimTeam> teams;
}

/// One page of a season's teams, best first.
class Match13YearTeams {
  Match13YearTeams({
    required this.year,
    required this.page,
    required this.limit,
    required this.total,
    required this.nextPage,
    required this.teams,
  });

  factory Match13YearTeams.fromJson(Map<String, dynamic> json) {
    return Match13YearTeams(
      year: _int(json['year']),
      page: _int(json['page']),
      limit: _int(json['limit']),
      total: _int(json['total']),
      nextPage: (json['nextPage'] as num?)?.toInt(),
      teams: _list(json['teams'], Match13TeamSeason.fromJson),
    );
  }

  final int year;
  final int page;
  final int limit;
  final int total;

  /// Null on the last page.
  final int? nextPage;

  /// Second robots and demo entries are left out. Rows carry no
  /// `components`.
  final List<Match13TeamSeason> teams;
}

/// The total the model expects a cutline to land on, with its 10th and 90th
/// percentiles.
class Match13Cutline {
  Match13Cutline({required this.q10, required this.q50, required this.q90});

  factory Match13Cutline.fromJson(Map<String, dynamic> json) {
    return Match13Cutline(
      q10: _num(json['q10']),
      q50: _num(json['q50']),
      q90: _num(json['q90']),
    );
  }

  final double q10;
  final double q50;
  final double q90;
}

/// One pool of district championship seats.
class Match13DistrictPool {
  Match13DistrictPool({
    required this.name,
    required this.capacity,
    required this.autos,
    required this.seatsByPoints,
    required this.cutline,
  });

  factory Match13DistrictPool.fromJson(Map<String, dynamic> json) {
    final cutline = (json['cutline'] as Map?)?.cast<String, dynamic>();
    return Match13DistrictPool(
      name: json['name'] as String? ?? '',
      capacity: _int(json['capacity']),
      autos: _int(json['autos']),
      seatsByPoints: _int(json['seatsByPoints']),
      cutline: cutline == null ? null : Match13Cutline.fromJson(cutline),
    );
  }

  final String name;

  /// How many seats the pool has.
  final int capacity;

  /// How many of those an award already took.
  final int autos;

  /// How many points can still win.
  final int seatsByPoints;

  /// What the model expects the last seat to need.
  final Match13Cutline? cutline;
}

/// What one team scored at one event toward a district or regional standing.
class Match13StandingEvent {
  Match13StandingEvent({
    required this.eventKey,
    required this.qual,
    required this.elim,
    required this.alliance,
    required this.award,
    required this.rookie,
    required this.counted,
  });

  factory Match13StandingEvent.fromJson(Map<String, dynamic> json) {
    return Match13StandingEvent(
      eventKey: json['eventKey'] as String? ?? '',
      qual: _num(json['qual']),
      elim: _num(json['elim']),
      alliance: _num(json['alliance']),
      award: _num(json['award']),
      rookie: _numOrNull(json['rookie']),
      counted: _bool(json['counted']),
    );
  }

  final String eventKey;
  final double qual;
  final double elim;
  final double alliance;
  final double award;

  /// Only the regional pool pays rookie points per event; null on a district
  /// row, which carries the rookie bonus once on the team instead.
  final double? rookie;

  /// False when this event's points do not score toward the standing.
  final bool counted;
}

/// Where the model expects a team to end up against a seat it is chasing.
///
/// `inRange` means the model expects the team to finish inside the seats
/// points decide, counting past the teams above it an award has already
/// seated. That is an ordering, not a probability threshold.
enum Match13SeatStatus {
  qualified('qualified'),
  locked('locked'),
  declined('declined'),
  inRange('in_range'),
  outOfRange('out_of_range'),
  lockedOut('locked_out');

  const Match13SeatStatus(this.wireName);

  final String wireName;

  /// Null for an unknown or absent value, which is what a `tba`-sourced
  /// standing sends for every forecast field.
  static Match13SeatStatus? fromWire(Object? value) {
    for (final status in Match13SeatStatus.values) {
      if (status.wireName == value) return status;
    }
    return null;
  }
}

/// Where the standings came from.
///
/// `tba` means FIRST's published ranking, and every forecast field on every
/// row is null. `engine` means match13's own model, which fills them in.
enum Match13StandingSource {
  engine('engine'),
  tba('tba');

  const Match13StandingSource(this.wireName);

  final String wireName;

  static Match13StandingSource fromWire(Object? value) {
    return value == 'tba'
        ? Match13StandingSource.tba
        : Match13StandingSource.engine;
  }
}

/// One team's row in a district standing.
class Match13DistrictTeam {
  Match13DistrictTeam({
    required this.teamNumber,
    required this.rank,
    required this.pool,
    required this.total,
    required this.rookieBonus,
    required this.adjustments,
    required this.events,
    required this.mean,
    required this.q10,
    required this.q50,
    required this.q90,
    required this.pDcmp,
    required this.pCmp,
    required this.dcmpStatus,
    required this.cmpStatus,
  });

  factory Match13DistrictTeam.fromJson(Map<String, dynamic> json) {
    return Match13DistrictTeam(
      teamNumber: _int(json['teamNumber']),
      rank: _int(json['rank']),
      pool: json['pool'] as String?,
      total: _num(json['total']),
      rookieBonus: _num(json['rookieBonus']),
      adjustments: _num(json['adjustments']),
      events: _list(json['events'], Match13StandingEvent.fromJson),
      mean: _numOrNull(json['mean']),
      q10: _numOrNull(json['q10']),
      q50: _numOrNull(json['q50']),
      q90: _numOrNull(json['q90']),
      pDcmp: _numOrNull(json['pDcmp']),
      pCmp: _numOrNull(json['pCmp']),
      dcmpStatus: Match13SeatStatus.fromWire(json['dcmpStatus']),
      cmpStatus: Match13SeatStatus.fromWire(json['cmpStatus']),
    );
  }

  final int teamNumber;
  final int rank;

  /// Which seat pool the team sits in, null when it sits in none.
  final String? pool;

  final double total;
  final double rookieBonus;
  final double adjustments;
  final List<Match13StandingEvent> events;

  /// Forecast for the team's final total. Null on a `tba`-sourced standing.
  final double? mean;
  final double? q10;
  final double? q50;
  final double? q90;

  /// The team's odds of a district championship and a championship seat.
  /// Null on a `tba`-sourced standing.
  final double? pDcmp;
  final double? pCmp;

  final Match13SeatStatus? dcmpStatus;
  final Match13SeatStatus? cmpStatus;
}

/// A district's standings, in rank order, with a forecast for each seat.
class Match13DistrictTeams {
  Match13DistrictTeams({
    required this.code,
    required this.districtKey,
    required this.year,
    required this.source,
    required this.capacity,
    required this.cmpSlots,
    required this.cmpPrequalSlots,
    required this.pools,
    required this.cmpCutline,
    required this.teams,
  });

  factory Match13DistrictTeams.fromJson(Map<String, dynamic> json) {
    final cutline = (json['cmpCutline'] as Map?)?.cast<String, dynamic>();
    return Match13DistrictTeams(
      code: json['code'] as String? ?? '',
      districtKey: json['districtKey'] as String? ?? '',
      year: _int(json['year']),
      source: Match13StandingSource.fromWire(json['source']),
      capacity: _int(json['capacity']),
      cmpSlots: _int(json['cmpSlots']),
      cmpPrequalSlots: _int(json['cmpPrequalSlots']),
      pools: _list(json['pools'], Match13DistrictPool.fromJson),
      cmpCutline: cutline == null ? null : Match13Cutline.fromJson(cutline),
      teams: _list(json['teams'], Match13DistrictTeam.fromJson),
    );
  }

  /// The district code, written as The Blue Alliance writes it: `fim`, `ne`,
  /// `pnw`.
  final String code;

  final String districtKey;
  final int year;
  final Match13StandingSource source;

  /// The district's total district championship capacity.
  final int capacity;

  /// The district's championship seats.
  final int cmpSlots;

  /// Teams that held a championship seat before the season started, on top of
  /// [cmpSlots].
  final int cmpPrequalSlots;

  final List<Match13DistrictPool> pools;

  /// What the model expects the last championship seat to need.
  final Match13Cutline? cmpCutline;

  final List<Match13DistrictTeam> teams;
}

/// The season's published regional pool rules.
class Match13RegionalRules {
  Match13RegionalRules({
    required this.regionalSeats,
    required this.direct,
    required this.usDirect,
    required this.internationalDirect,
    required this.provisional,
  });

  factory Match13RegionalRules.fromJson(Map<String, dynamic> json) {
    return Match13RegionalRules(
      regionalSeats: _int(json['regionalSeats']),
      direct: json['direct'] as String? ?? '',
      usDirect: _int(json['usDirect']),
      internationalDirect: _int(json['internationalDirect']),
      provisional: _bool(json['provisional']),
    );
  }

  final int regionalSeats;
  final String direct;
  final int usDirect;
  final int internationalDirect;

  /// True when these are last season's rules carried forward.
  final bool provisional;
}

/// How the pool's seats have been awarded so far.
class Match13RegionalSeats {
  Match13RegionalSeats({
    required this.direct,
    required this.pool,
    required this.prequal,
    required this.declined,
    required this.directTotal,
  });

  factory Match13RegionalSeats.fromJson(Map<String, dynamic> json) {
    return Match13RegionalSeats(
      direct: _int(json['direct']),
      pool: _int(json['pool']),
      prequal: _int(json['prequal']),
      declined: _int(json['declined']),
      directTotal: _int(json['directTotal']),
    );
  }

  final int direct;
  final int pool;
  final int prequal;
  final int declined;

  /// Every direct seat the season's regionals pay between them.
  final int directTotal;
}

/// One team's row in the regional pool standing.
class Match13RegionalTeam {
  Match13RegionalTeam({
    required this.teamNumber,
    required this.rank,
    required this.total,
    required this.projected,
    required this.rookieBonus,
    required this.adjustments,
    required this.events,
    required this.mean,
    required this.q10,
    required this.q50,
    required this.q90,
    required this.pCmp,
    required this.status,
    required this.via,
  });

  factory Match13RegionalTeam.fromJson(Map<String, dynamic> json) {
    return Match13RegionalTeam(
      teamNumber: _int(json['teamNumber']),
      rank: (json['rank'] as num?)?.toInt(),
      total: _num(json['total']),
      projected: _numOrNull(json['projected']),
      rookieBonus: _num(json['rookieBonus']),
      adjustments: _num(json['adjustments']),
      events: _list(json['events'], Match13StandingEvent.fromJson),
      mean: _numOrNull(json['mean']),
      q10: _numOrNull(json['q10']),
      q50: _numOrNull(json['q50']),
      q90: _numOrNull(json['q90']),
      pCmp: _numOrNull(json['pCmp']),
      status: Match13SeatStatus.fromWire(json['status']),
      via: json['via'] as String?,
    );
  }

  final int teamNumber;

  /// Null for a team that has played no regional.
  final int? rank;

  final double total;

  /// The points the model expects a second regional to pay a team that has
  /// played one. Part of [total], and null once two regionals count.
  final double? projected;

  final double rookieBonus;
  final double adjustments;
  final List<Match13StandingEvent> events;

  /// Forecast for the team's final total.
  final double? mean;
  final double? q10;
  final double? q50;
  final double? q90;

  /// The team's odds of a championship seat.
  final double? pCmp;

  final Match13SeatStatus? status;

  /// How the team earned its seat, null until it holds one.
  final String? via;
}

/// The regional pool's standings, in rank order, with a forecast for each
/// seat. The pool counts a team's first two regionals.
class Match13RegionalTeams {
  Match13RegionalTeams({
    required this.year,
    required this.source,
    required this.rules,
    required this.seats,
    required this.regionalsTotal,
    required this.regionalsComplete,
    required this.poolCutline,
    required this.teams,
  });

  factory Match13RegionalTeams.fromJson(Map<String, dynamic> json) {
    final rules = (json['rules'] as Map?)?.cast<String, dynamic>();
    final seats = (json['seats'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final regionals = (json['regionals'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final cutline = (json['poolCutline'] as Map?)?.cast<String, dynamic>();
    return Match13RegionalTeams(
      year: _int(json['year']),
      source: Match13StandingSource.fromWire(json['source']),
      rules: rules == null ? null : Match13RegionalRules.fromJson(rules),
      seats: Match13RegionalSeats.fromJson(seats),
      regionalsTotal: _int(regionals['total']),
      regionalsComplete: _int(regionals['complete']),
      poolCutline: cutline == null ? null : Match13Cutline.fromJson(cutline),
      teams: _list(json['teams'], Match13RegionalTeam.fromJson),
    );
  }

  final int year;
  final Match13StandingSource source;

  /// Null when the season has published none.
  final Match13RegionalRules? rules;

  final Match13RegionalSeats seats;

  /// How many regionals the season has, and how many have finished.
  final int regionalsTotal;
  final int regionalsComplete;

  /// What the model expects the pool's last seat to need.
  final Match13Cutline? poolCutline;

  final List<Match13RegionalTeam> teams;
}
