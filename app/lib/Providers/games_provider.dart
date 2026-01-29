import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../Models/game.dart';
import 'api_service.dart';

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

  /// Core fetch logic
  Future<GamesState> _fetchGames() async {
    final apiService = ref.read(apiServiceProvider);

    // Fetch both ESPN data and predictions in parallel
    final espnFuture = apiService.fetchEspnScoreboard();
    final predictionsFuture = apiService.fetchPredictions();

    final previousGamesById = {
      for (final game in state.valueOrNull?.games ?? <Game>[]) game.id: game,
    };

    final espnData = await espnFuture;
    final predictionsData = await predictionsFuture;

    final events = espnData['events'] as List<dynamic>? ?? [];
    final predictionsList = predictionsData?['games'] as List<dynamic>? ?? [];
    
    debugPrint('Fetched ${events.length} games from ESPN');
    debugPrint('Fetched ${predictionsList.length} predictions from API');
    if (predictionsData == null) {
      debugPrint('Warning: Predictions API returned null - check API connection');
    }

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
        continue;
      }
    }

    return GamesState(
      games: games,
      lastFetchTime: DateTime.now(),
      isRefreshing: false,
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
    final gameDateTime = DateTime.tryParse(dateStr)?.toLocal();
    final formattedDate = gameDateTime != null
        ? '${_getMonthName(gameDateTime.month)} ${gameDateTime.day}'
        : 'TBD';
    final formattedTime = gameDateTime != null
        ? '${_formatHour(gameDateTime.hour)}:${gameDateTime.minute.toString().padLeft(2, '0')} ${gameDateTime.hour >= 12 ? 'PM' : 'AM'}'
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
      }
    }

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
    );
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
