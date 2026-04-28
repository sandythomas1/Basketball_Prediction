import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../Models/game.dart';
import '../Services/cache_service.dart';
import 'api_service.dart';
import 'league_provider.dart';

/// State class to hold games data with metadata
class GamesState {
  final List<Game> games;
  final DateTime? lastFetchTime;
  final bool isRefreshing;

  const GamesState({
    this.games = const [],
    this.lastFetchTime,
    this.isRefreshing = false,
  });

  GamesState copyWith({
    List<Game>? games,
    DateTime? lastFetchTime,
    bool? isRefreshing,
  }) {
    return GamesState(
      games: games ?? this.games,
      lastFetchTime: lastFetchTime ?? this.lastFetchTime,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  /// Filter for live games only
  List<Game> get liveGames => games.where((g) => g.isLive).toList();

  /// Filter for finished games only
  List<Game> get finishedGames => games.where((g) => g.isFinal).toList();

  /// Check if there are any live games
  bool get hasLiveGames => games.any((g) => g.isLive);
}

/// AsyncNotifier for managing games state
class GamesNotifier extends AsyncNotifier<GamesState> {
  // Rate limiting: minimum 30 seconds between API calls
  static const Duration _minFetchInterval = Duration(seconds: 30);

  @override
  Future<GamesState> build() async {
    // Initial fetch on provider creation
    return _fetchGames();
  }

  /// Check if enough time has passed since last fetch
  bool _canFetch(DateTime? lastFetchTime) {
    if (lastFetchTime == null) return true;
    return DateTime.now().difference(lastFetchTime) >= _minFetchInterval;
  }

  /// Refresh games data (called by pull-to-refresh)
  Future<void> refresh() async {
    final currentState = state.valueOrNull;
    
    // Rate limiting check
    if (!_canFetch(currentState?.lastFetchTime)) {
      debugPrint('Rate limited: Please wait before refreshing');
      throw Exception('Please wait before refreshing again');
    }

    // Set refreshing state
    if (currentState != null) {
      state = AsyncValue.data(currentState.copyWith(isRefreshing: true));
    }

    try {
      final newState = await _fetchGames();
      state = AsyncValue.data(newState);
    } catch (e, _) {
      // Keep existing data on error during refresh
      if (currentState != null) {
        state = AsyncValue.data(currentState.copyWith(isRefreshing: false));
      }
      rethrow;
    }
  }

  /// Core fetch logic.
  ///
  /// Strategy:
  /// 1. Try the combined backend endpoint (games + predictions in one call).
  /// 2. If that fails, fall back to ESPN direct + separate predictions call.
  /// 3. If everything fails, load from local cache.
  Future<GamesState> _fetchGames() async {
    final apiService = ref.read(apiServiceProvider);
    final league = ref.read(leagueProvider);
    final previousGamesById = {
      for (final game in state.valueOrNull?.games ?? <Game>[]) game.id: game,
    };

    // Always fetch ESPN scoreboard — it carries quarter scores and leaders
    // that the backend schema doesn't include.
    Map<String, dynamic>? espnRaw;
    try {
      espnRaw = await apiService.fetchEspnScoreboard(league);
    } catch (e) {
      debugPrint('ESPN scoreboard fetch failed: $e');
    }

    // Build a lookup of boxscore data keyed by home+away team name.
    final boxScoreLookup = <String, _EspnBoxScore>{};
    if (espnRaw != null) {
      final events = espnRaw['events'] as List<dynamic>? ?? [];
      for (final event in events) {
        final bs = _extractBoxScore(event);
        if (bs != null) boxScoreLookup[bs.key] = bs;
      }
    }

    // --- Attempt 1: Combined backend endpoint ---
    final combined = await apiService.fetchGamesWithPredictions(league);
    if (combined != null) {
      final gamesList = combined['games'] as List<dynamic>? ?? [];
      debugPrint('Fetched ${gamesList.length} games+predictions from backend');
      final games = _parseBackendGames(gamesList, previousGamesById);
      if (games.isNotEmpty) {
        final enriched = _enrichWithBoxScores(games, boxScoreLookup);
        return GamesState(games: enriched, lastFetchTime: DateTime.now());
      }
    }

    // --- Attempt 2: ESPN direct + separate predictions ---
    if (espnRaw != null) {
      try {
        final predictionsData = await apiService.fetchPredictions(league);
        final events = espnRaw['events'] as List<dynamic>? ?? [];
        final predictionsList =
            predictionsData?['games'] as List<dynamic>? ?? [];

        debugPrint('Fallback: ${events.length} ESPN + ${predictionsList.length} predictions');

        final List<Game> games = [];
        for (final event in events) {
          try {
            final game = _parseGame(event, predictionsList);
            if (game != null) {
              final previous = previousGamesById[game.id];
              games.add(_mergeWithCachedPrediction(game, previous));
            }
          } catch (e) {
            debugPrint('Error parsing game: $e');
          }
        }

        if (games.isNotEmpty) {
          return GamesState(games: games, lastFetchTime: DateTime.now());
        }
      } catch (e) {
        debugPrint('Fallback predictions failed: $e');
      }
    }

    // --- Attempt 3: Offline cache ---
    final cached = await CacheService.instance.loadGamesCache();
    if (cached != null) {
      debugPrint('Loaded games from offline cache');
      final gamesList = cached['games'] as List<dynamic>? ?? [];
      final games = _parseBackendGames(gamesList, previousGamesById);
      if (games.isNotEmpty) {
        return GamesState(games: games, lastFetchTime: DateTime.now());
      }
    }

    return GamesState(lastFetchTime: DateTime.now());
  }

  /// Parse games from the combined backend response format.
  List<Game> _parseBackendGames(
    List<dynamic> gamesList,
    Map<String, Game> previousGamesById,
  ) {
    final List<Game> games = [];
    for (final g in gamesList) {
      try {
        final game = _parseBackendGame(g as Map<String, dynamic>);
        if (game != null) {
          final previous = previousGamesById[game.id];
          games.add(_mergeWithCachedPrediction(game, previous));
        }
      } catch (e) {
        debugPrint('Error parsing backend game: $e');
      }
    }
    return games;
  }

  /// Parse a single game from the backend's GameWithPrediction JSON.
  Game? _parseBackendGame(Map<String, dynamic> g) {
    final homeTeam = g['home_team'] as String? ?? '';
    final awayTeam = g['away_team'] as String? ?? '';
    if (homeTeam.isEmpty || awayTeam.isEmpty) return null;

    final dateStr = g['game_date'] as String? ?? '';
    final timeStr = g['game_time'] as String? ?? '';
    final status = g['status'] as String? ?? 'Scheduled';

    // Append Z to force UTC interpretation — backend returns bare UTC strings.
    final parsedUtc = DateTime.tryParse('${dateStr}T${timeStr}Z');
    final gameDateTime = parsedUtc != null ? _toPst(parsedUtc) : null;
    final formattedDate = gameDateTime != null
        ? '${_getMonthName(gameDateTime.month)} ${gameDateTime.day}'
        : dateStr;
    final formattedTime = gameDateTime != null
        ? '${_formatHour(gameDateTime.hour)}:${gameDateTime.minute.toString().padLeft(2, '0')} ${gameDateTime.hour >= 12 ? 'PM' : 'AM'} PT'
        : timeStr;

    final raw = '${homeTeam}_vs_${awayTeam}_$dateStr'.toLowerCase();
    final gameId = raw.replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');

    double? homeWinProb;
    double? awayWinProb;
    String? confidenceTier;
    String? favoredTeam;
    double? homeElo;
    double? awayElo;
    int? confidenceScore;
    String? confidenceQualifier;
    Map<String, dynamic>? confidenceFactors;
    List<String>? homeInjuries;
    List<String>? awayInjuries;
    String? injuryAdvantage;

    final pred = g['prediction'] as Map<String, dynamic>?;
    final ctx = g['context'] as Map<String, dynamic>?;

    if (pred != null) {
      homeWinProb = (pred['home_win_prob'] as num?)?.toDouble();
      awayWinProb = (pred['away_win_prob'] as num?)?.toDouble();
      confidenceTier = pred['confidence'] as String?;
      confidenceScore = pred['confidence_score'] as int?;
      confidenceQualifier = pred['confidence_qualifier'] as String?;
      confidenceFactors = pred['confidence_factors'] as Map<String, dynamic>?;
      final favored = pred['favored'] as String?;
      favoredTeam = favored == 'home' ? homeTeam : (favored == 'away' ? awayTeam : null);
    }

    if (ctx != null) {
      homeElo = (ctx['home_elo'] as num?)?.toDouble();
      awayElo = (ctx['away_elo'] as num?)?.toDouble();
      final hi = ctx['home_injuries'] as List<dynamic>?;
      final ai = ctx['away_injuries'] as List<dynamic>?;
      if (hi != null) homeInjuries = hi.map((e) => e.toString()).toList();
      if (ai != null) awayInjuries = ai.map((e) => e.toString()).toList();
      injuryAdvantage = ctx['injury_advantage'] as String?;
    }

    return Game(
      id: gameId,
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      date: formattedDate,
      time: formattedTime,
      status: status,
      homeScore: (g['home_score'] ?? '').toString(),
      awayScore: (g['away_score'] ?? '').toString(),
      homeWinProb: homeWinProb,
      awayWinProb: awayWinProb,
      confidenceTier: confidenceTier,
      favoredTeam: favoredTeam,
      homeElo: homeElo,
      awayElo: awayElo,
      confidenceScore: confidenceScore,
      confidenceQualifier: confidenceQualifier,
      confidenceFactors: confidenceFactors,
      homeInjuries: homeInjuries,
      awayInjuries: awayInjuries,
      injuryAdvantage: injuryAdvantage,
    );
  }

  Game _mergeWithCachedPrediction(Game current, Game? previous) {
    if (previous == null) return current;

    final hasCurrentPrediction = current.homeWinProb != null ||
        current.awayWinProb != null ||
        current.confidenceTier != null ||
        current.favoredTeam != null ||
        current.homeElo != null ||
        current.awayElo != null;

    if (hasCurrentPrediction || !current.isLive) {
      return current;
    }

    return current.copyWith(
      homeWinProb: previous.homeWinProb,
      awayWinProb: previous.awayWinProb,
      confidenceTier: previous.confidenceTier,
      favoredTeam: previous.favoredTeam,
      homeElo: previous.homeElo,
      awayElo: previous.awayElo,
      confidenceScore: previous.confidenceScore,
      confidenceQualifier: previous.confidenceQualifier,
      confidenceFactors: previous.confidenceFactors,
      homeInjuries: previous.homeInjuries,
      awayInjuries: previous.awayInjuries,
      injuryAdvantage: previous.injuryAdvantage,
    );
  }

  /// Parse a single game from ESPN event data
  Game? _parseGame(Map<String, dynamic> event, List<dynamic> predictions) {
    final gameId = event['id'] as String? ?? _fallbackGameId(event);
    final competitions = event['competitions'] as List<dynamic>?;
    if (competitions == null || competitions.isEmpty) return null;

    final competition = competitions[0];
    final competitors = competition['competitors'] as List<dynamic>?;
    if (competitors == null || competitors.length < 2) return null;

    // Find home and away teams
    String homeTeam = '';
    String awayTeam = '';
    String homeScore = '';
    String awayScore = '';

    for (final competitor in competitors) {
      final team = competitor['team'];
      final teamName = team?['displayName'] ?? 'Unknown';
      final score = competitor['score'] ?? '';

      if (competitor['homeAway'] == 'home') {
        homeTeam = teamName;
        homeScore = score;
      } else {
        awayTeam = teamName;
        awayScore = score;
      }
    }

    // Parse date and time
    final dateStr = event['date'] as String? ?? '';
    final parsedUtc = DateTime.tryParse(dateStr)?.toUtc();
    final gameDateTime = parsedUtc != null ? _toPst(parsedUtc) : null;
    final formattedDate = gameDateTime != null
        ? '${_getMonthName(gameDateTime.month)} ${gameDateTime.day}'
        : 'TBD';
    final formattedTime = gameDateTime != null
        ? '${_formatHour(gameDateTime.hour)}:${gameDateTime.minute.toString().padLeft(2, '0')} ${gameDateTime.hour >= 12 ? 'PM' : 'AM'} PT'
        : 'TBD';

    // Get game status
    final status = event['status']?['type']?['description'] ?? 'Scheduled';

    // Find matching prediction from API
    final prediction = _findPrediction(predictions, homeTeam, awayTeam);
    if (prediction != null) {
      debugPrint('✓ Matched prediction for $homeTeam vs $awayTeam');
    } else if (predictions.isNotEmpty) {
      debugPrint('✗ No prediction match for $homeTeam vs $awayTeam');
    }

    // Extract prediction data
    double? homeWinProb;
    double? awayWinProb;
    String? confidenceTier;
    String? favoredTeam;
    double? homeElo;
    double? awayElo;
    int? confidenceScore;
    String? confidenceQualifier;
    Map<String, dynamic>? confidenceFactors;
    List<String>? homeInjuries;
    List<String>? awayInjuries;
    String? injuryAdvantage;

    if (prediction != null) {
      final predInfo = prediction['prediction'] as Map<String, dynamic>?;
      final context = prediction['context'] as Map<String, dynamic>?;

      if (predInfo != null) {
        homeWinProb = (predInfo['home_win_prob'] as num?)?.toDouble();
        awayWinProb = (predInfo['away_win_prob'] as num?)?.toDouble();
        confidenceTier = predInfo['confidence'] as String?;
        
        // Extract new confidence fields
        confidenceScore = predInfo['confidence_score'] as int?;
        confidenceQualifier = predInfo['confidence_qualifier'] as String?;
        confidenceFactors = predInfo['confidence_factors'] as Map<String, dynamic>?;

        final favored = predInfo['favored'] as String?;
        if (favored == 'home') {
          favoredTeam = homeTeam;
        } else if (favored == 'away') {
          favoredTeam = awayTeam;
        }
      }

      if (context != null) {
        homeElo = (context['home_elo'] as num?)?.toDouble();
        awayElo = (context['away_elo'] as num?)?.toDouble();
        
        // NEW: Extract injury data
        final homeInjuriesList = context['home_injuries'] as List<dynamic>?;
        final awayInjuriesList = context['away_injuries'] as List<dynamic>?;
        
        if (homeInjuriesList != null) {
          homeInjuries = homeInjuriesList.map((e) => e.toString()).toList();
        }
        if (awayInjuriesList != null) {
          awayInjuries = awayInjuriesList.map((e) => e.toString()).toList();
        }
        
        injuryAdvantage = context['injury_advantage'] as String?;
      }
    }

    // Extract boxscore data from the raw ESPN event
    final bs = _extractBoxScore(event);

    return Game(
      id: gameId,
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      date: formattedDate,
      time: formattedTime,
      status: status,
      homeScore: homeScore,
      awayScore: awayScore,
      homeWinProb: homeWinProb,
      awayWinProb: awayWinProb,
      confidenceTier: confidenceTier,
      favoredTeam: favoredTeam,
      homeElo: homeElo,
      awayElo: awayElo,
      confidenceScore: confidenceScore,
      confidenceQualifier: confidenceQualifier,
      confidenceFactors: confidenceFactors,
      homeInjuries: homeInjuries,
      awayInjuries: awayInjuries,
      injuryAdvantage: injuryAdvantage,
      homeQuarters: bs?.homeQuarters,
      awayQuarters: bs?.awayQuarters,
      leaders: bs?.leaders,
    );
  }

  // ---------------------------------------------------------------
  // Boxscore extraction helpers
  // ---------------------------------------------------------------

  /// Merge boxscore data from the ESPN lookup into the game list.
  List<Game> _enrichWithBoxScores(
    List<Game> games,
    Map<String, _EspnBoxScore> lookup,
  ) {
    if (lookup.isEmpty) return games;
    return games.map((g) {
      final key = '${g.homeTeam}||${g.awayTeam}'.toLowerCase();
      final bs = lookup[key];
      if (bs == null) return g;
      return g.copyWith(
        homeQuarters: bs.homeQuarters,
        awayQuarters: bs.awayQuarters,
        leaders: bs.leaders,
        // Prefer ESPN live score strings when available
        homeScore: bs.homeTotal > 0 ? bs.homeTotal.toString() : null,
        awayScore: bs.awayTotal > 0 ? bs.awayTotal.toString() : null,
      );
    }).toList();
  }

  /// Pull quarter linescores + per-category leaders out of a raw ESPN event.
  _EspnBoxScore? _extractBoxScore(dynamic event) {
    try {
      final competitions = event['competitions'] as List<dynamic>?;
      if (competitions == null || competitions.isEmpty) return null;
      final competition = competitions[0];
      final competitors = competition['competitors'] as List<dynamic>?;
      if (competitors == null || competitors.length < 2) return null;

      String homeTeam = '';
      String awayTeam = '';
      List<int> homeQ = [];
      List<int> awayQ = [];
      int homeTotal = 0;
      int awayTotal = 0;
      List<GameLeader> leaders = [];

      for (final comp in competitors) {
        final isHome = comp['homeAway'] == 'home';
        final teamName = comp['team']?['displayName'] ?? '';

        // Linescores
        final linescores = comp['linescores'] as List<dynamic>? ?? [];
        final quarters = linescores
            .map((ls) => ((ls['value'] as num?)?.toInt()) ?? 0)
            .toList();

        final totalScore = int.tryParse((comp['score'] ?? '0').toString()) ?? 0;

        if (isHome) {
          homeTeam = teamName;
          homeQ = quarters;
          homeTotal = totalScore;
        } else {
          awayTeam = teamName;
          awayQ = quarters;
          awayTotal = totalScore;
        }

        // Per-category leaders (points, rebounds, assists)
        final leaderCategories = comp['leaders'] as List<dynamic>? ?? [];
        for (final cat in leaderCategories) {
          final catName = cat['name'] as String? ?? '';
          final topLeaders = cat['leaders'] as List<dynamic>? ?? [];
          if (topLeaders.isEmpty) continue;
          final top = topLeaders[0];
          final playerName =
              top['athlete']?['displayName'] as String? ?? '';
          final displayValue = top['displayValue'] as String? ?? '';
          if (playerName.isNotEmpty) {
            leaders.add(GameLeader(
              category: catName,
              playerName: playerName,
              displayValue: displayValue,
              isHome: isHome,
            ));
          }
        }
      }

      if (homeTeam.isEmpty || awayTeam.isEmpty) return null;

      return _EspnBoxScore(
        homeTeam: homeTeam,
        awayTeam: awayTeam,
        homeQuarters: homeQ,
        awayQuarters: awayQ,
        homeTotal: homeTotal,
        awayTotal: awayTotal,
        leaders: leaders,
      );
    } catch (_) {
      return null;
    }
  }

  /// Find matching prediction for a game by team names
  Map<String, dynamic>? _findPrediction(
    List<dynamic> predictions,
    String homeTeam,
    String awayTeam,
  ) {
    for (final pred in predictions) {
      final predHome = pred['home_team'] as String? ?? '';
      final predAway = pred['away_team'] as String? ?? '';

      if (_teamsMatch(predHome, homeTeam) && _teamsMatch(predAway, awayTeam)) {
        return pred as Map<String, dynamic>;
      }
    }
    return null;
  }

  /// Check if two team names match (handles slight variations)
  bool _teamsMatch(String apiTeam, String espnTeam) {
    final api = apiTeam.toLowerCase().trim();
    final espn = espnTeam.toLowerCase().trim();
    return api == espn || api.contains(espn) || espn.contains(api);
  }

  /// Converts a UTC [DateTime] to PST (UTC-8) or PDT (UTC-7) based on US DST.
  DateTime _toPst(DateTime utc) {
    return utc.subtract(Duration(hours: _isPdt(utc) ? 7 : 8));
  }

  /// Returns true when US daylight saving time (PDT, UTC-7) is active.
  bool _isPdt(DateTime utc) {
    final year = utc.year;
    final marchFirst = DateTime.utc(year, 3, 1);
    final dstStart = marchFirst.add(
      Duration(days: (7 - (marchFirst.weekday % 7)) % 7 + 7),
    );
    final novFirst = DateTime.utc(year, 11, 1);
    final dstEnd = novFirst.add(
      Duration(days: (7 - (novFirst.weekday % 7)) % 7),
    );
    return utc.isAfter(dstStart) && utc.isBefore(dstEnd);
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12';
    if (hour > 12) return (hour - 12).toString();
    return hour.toString();
  }

  String _fallbackGameId(Map<String, dynamic> event) {
    final dateStr = event['date'] as String? ?? '';
    final competitions = event['competitions'] as List<dynamic>? ?? [];
    final competition = competitions.isNotEmpty ? competitions[0] : null;
    final competitors = competition?['competitors'] as List<dynamic>? ?? [];
    String homeTeam = '';
    String awayTeam = '';
    for (final competitor in competitors) {
      final team = competitor['team'];
      final teamName = team?['displayName'] ?? 'unknown';
      if (competitor['homeAway'] == 'home') {
        homeTeam = teamName;
      } else {
        awayTeam = teamName;
      }
    }
    final raw = '${homeTeam}_vs_${awayTeam}_$dateStr'.toLowerCase();
    return raw.replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
  }
}

/// Main games provider
final gamesProvider = AsyncNotifierProvider<GamesNotifier, GamesState>(() {
  return GamesNotifier();
});

/// Convenience provider for live games only
final liveGamesProvider = Provider<List<Game>>((ref) {
  final gamesState = ref.watch(gamesProvider);
  return gamesState.valueOrNull?.liveGames ?? [];
});

/// Convenience provider for finished games only
final finishedGamesProvider = Provider<List<Game>>((ref) {
  final gamesState = ref.watch(gamesProvider);
  return gamesState.valueOrNull?.finishedGames ?? [];
});

/// Provider to check if there are live games (for badge)
final hasLiveGamesProvider = Provider<bool>((ref) {
  final gamesState = ref.watch(gamesProvider);
  return gamesState.valueOrNull?.hasLiveGames ?? false;
});

/// Internal helper holding boxscore data extracted from an ESPN event.
class _EspnBoxScore {
  final String homeTeam;
  final String awayTeam;
  final List<int> homeQuarters;
  final List<int> awayQuarters;
  final int homeTotal;
  final int awayTotal;
  final List<GameLeader> leaders;

  _EspnBoxScore({
    required this.homeTeam,
    required this.awayTeam,
    required this.homeQuarters,
    required this.awayQuarters,
    required this.homeTotal,
    required this.awayTotal,
    required this.leaders,
  });

  String get key => '$homeTeam||$awayTeam'.toLowerCase();
}
