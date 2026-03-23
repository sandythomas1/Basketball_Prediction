// Playoff data models for the Signal Sports app.
// These models are completely separate from the regular season Game model.
// They represent playoff bracket state, series records, and game predictions.

// ============================================================================
// Series Game (one completed/scheduled game within a series)
// ============================================================================

class PlayoffSeriesGame {
  final int gameNumber;
  final String gameDate;
  final int homeTeamId;
  final int awayTeamId;
  final int? homeScore;
  final int? awayScore;
  final int? winnerId;
  final String status; // "scheduled" | "final"

  const PlayoffSeriesGame({
    required this.gameNumber,
    required this.gameDate,
    required this.homeTeamId,
    required this.awayTeamId,
    this.homeScore,
    this.awayScore,
    this.winnerId,
    required this.status,
  });

  bool get isFinal => status.toLowerCase() == 'final';

  factory PlayoffSeriesGame.fromJson(Map<String, dynamic> json) {
    return PlayoffSeriesGame(
      gameNumber: json['game_number'] as int? ?? 0,
      gameDate: json['game_date'] as String? ?? '',
      homeTeamId: json['home_team_id'] as int? ?? 0,
      awayTeamId: json['away_team_id'] as int? ?? 0,
      homeScore: json['home_score'] as int?,
      awayScore: json['away_score'] as int?,
      winnerId: json['winner_id'] as int?,
      status: json['status'] as String? ?? 'scheduled',
    );
  }
}

// ============================================================================
// Series Info (bracket-level summary of one series)
// ============================================================================

class PlayoffSeriesInfo {
  final String seriesId;
  final String roundName;
  final String conference;
  final int higherSeedId;
  final int lowerSeedId;
  final String higherSeedName;
  final String lowerSeedName;
  final int higherSeedWins;
  final int lowerSeedWins;
  final int gamesPlayed;
  final String status; // "upcoming" | "in_progress" | "complete"
  final int? winnerId;
  final String seriesContext;

  const PlayoffSeriesInfo({
    required this.seriesId,
    required this.roundName,
    required this.conference,
    required this.higherSeedId,
    required this.lowerSeedId,
    required this.higherSeedName,
    required this.lowerSeedName,
    required this.higherSeedWins,
    required this.lowerSeedWins,
    required this.gamesPlayed,
    required this.status,
    this.winnerId,
    required this.seriesContext,
  });

  bool get isComplete => status == 'complete';
  bool get isInProgress => status == 'in_progress';
  bool get isUpcoming => status == 'upcoming';

  /// Returns the name of the team leading the series, or null if tied/upcoming.
  String? get leadingTeamName {
    if (higherSeedWins > lowerSeedWins) return higherSeedName;
    if (lowerSeedWins > higherSeedWins) return lowerSeedName;
    return null;
  }

  /// Returns the leading team's win count.
  int get leadingWins => higherSeedWins > lowerSeedWins ? higherSeedWins : lowerSeedWins;

  /// Returns the trailing team's win count.
  int get trailingWins => higherSeedWins > lowerSeedWins ? lowerSeedWins : higherSeedWins;

  factory PlayoffSeriesInfo.fromJson(Map<String, dynamic> json) {
    return PlayoffSeriesInfo(
      seriesId: json['series_id'] as String? ?? '',
      roundName: json['round_name'] as String? ?? '',
      conference: json['conference'] as String? ?? '',
      higherSeedId: json['higher_seed_id'] as int? ?? 0,
      lowerSeedId: json['lower_seed_id'] as int? ?? 0,
      higherSeedName: json['higher_seed_name'] as String? ?? '',
      lowerSeedName: json['lower_seed_name'] as String? ?? '',
      higherSeedWins: json['higher_seed_wins'] as int? ?? 0,
      lowerSeedWins: json['lower_seed_wins'] as int? ?? 0,
      gamesPlayed: json['games_played'] as int? ?? 0,
      status: json['status'] as String? ?? 'upcoming',
      winnerId: json['winner_id'] as int?,
      seriesContext: json['series_context'] as String? ?? '',
    );
  }
}

// ============================================================================
// Playoff Bracket (full bracket for one season)
// ============================================================================

class PlayoffBracket {
  final int season;
  final String currentRound;
  final String fetchedAt;
  final List<PlayoffSeriesInfo> east;
  final List<PlayoffSeriesInfo> west;
  final PlayoffSeriesInfo? finals;
  final bool playoffsActive;

  const PlayoffBracket({
    required this.season,
    required this.currentRound,
    required this.fetchedAt,
    required this.east,
    required this.west,
    this.finals,
    this.playoffsActive = true,
  });

  factory PlayoffBracket.fromJson(Map<String, dynamic> json) {
    final eastList = (json['east'] as List<dynamic>? ?? [])
        .map((e) => PlayoffSeriesInfo.fromJson(e as Map<String, dynamic>))
        .toList();
    final westList = (json['west'] as List<dynamic>? ?? [])
        .map((e) => PlayoffSeriesInfo.fromJson(e as Map<String, dynamic>))
        .toList();
    final finalsData = json['finals'] as Map<String, dynamic>?;

    return PlayoffBracket(
      season: json['season'] as int? ?? 2026,
      currentRound: json['current_round'] as String? ?? 'first_round',
      fetchedAt: json['fetched_at'] as String? ?? '',
      east: eastList,
      west: westList,
      finals: finalsData != null ? PlayoffSeriesInfo.fromJson(finalsData) : null,
      playoffsActive: json['playoffs_active'] as bool? ?? true,
    );
  }
}

// ============================================================================
// Playoff Game Prediction
// ============================================================================

class PlayoffPrediction {
  final double homeWinProb;
  final double awayWinProb;
  final String confidence;
  final String favored;
  final int? confidenceScore;
  final String? confidenceQualifier;
  final double seriesWinProbHome;
  final double seriesWinProbAway;
  final String seriesContext;
  final int gameNumber;

  const PlayoffPrediction({
    required this.homeWinProb,
    required this.awayWinProb,
    required this.confidence,
    required this.favored,
    this.confidenceScore,
    this.confidenceQualifier,
    required this.seriesWinProbHome,
    required this.seriesWinProbAway,
    required this.seriesContext,
    required this.gameNumber,
  });

  factory PlayoffPrediction.fromJson(Map<String, dynamic> json) {
    return PlayoffPrediction(
      homeWinProb: (json['home_win_prob'] as num?)?.toDouble() ?? 0.5,
      awayWinProb: (json['away_win_prob'] as num?)?.toDouble() ?? 0.5,
      confidence: json['confidence'] as String? ?? '',
      favored: json['favored'] as String? ?? 'home',
      confidenceScore: json['confidence_score'] as int?,
      confidenceQualifier: json['confidence_qualifier'] as String?,
      seriesWinProbHome: (json['series_win_prob_home'] as num?)?.toDouble() ?? 0.5,
      seriesWinProbAway: (json['series_win_prob_away'] as num?)?.toDouble() ?? 0.5,
      seriesContext: json['series_context'] as String? ?? '',
      gameNumber: json['game_number'] as int? ?? 1,
    );
  }
}

// ============================================================================
// Playoff Game With Prediction (for today's games list)
// ============================================================================

class PlayoffGame {
  final String? seriesId;
  final String? roundName;
  final String? conference;
  final String gameDate;
  final String? gameTime;
  final int gameNumber;
  final String homeTeam;
  final String awayTeam;
  final int homeTeamId;
  final int awayTeamId;
  final int homeSeriesWins;
  final int awaySeriesWins;
  final PlayoffPrediction? prediction;
  final Map<String, dynamic>? context;

  const PlayoffGame({
    this.seriesId,
    this.roundName,
    this.conference,
    required this.gameDate,
    this.gameTime,
    required this.gameNumber,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.homeSeriesWins,
    required this.awaySeriesWins,
    this.prediction,
    this.context,
  });

  /// The series context badge label, e.g. "Game 5 · BOS leads 3-1"
  String get seriesLabel {
    final ctx = prediction?.seriesContext ?? 'Game $gameNumber';
    return 'Game $gameNumber · $ctx';
  }

  /// Whether this is an elimination game for either team.
  bool get isEliminationGame {
    return homeSeriesWins == 3 || awaySeriesWins == 3;
  }

  /// Whether this is a closeout opportunity for the home team.
  bool get isHomeCloseout => homeSeriesWins == 3;

  /// Whether this is a closeout opportunity for the away team.
  bool get isAwayCloseout => awaySeriesWins == 3;

  factory PlayoffGame.fromJson(Map<String, dynamic> json) {
    final predData = json['prediction'] as Map<String, dynamic>?;
    return PlayoffGame(
      seriesId: json['series_id'] as String?,
      roundName: json['round_name'] as String?,
      conference: json['conference'] as String?,
      gameDate: json['game_date'] as String? ?? '',
      gameTime: json['game_time'] as String?,
      gameNumber: json['game_number'] as int? ?? 1,
      homeTeam: json['home_team'] as String? ?? '',
      awayTeam: json['away_team'] as String? ?? '',
      homeTeamId: json['home_team_id'] as int? ?? 0,
      awayTeamId: json['away_team_id'] as int? ?? 0,
      homeSeriesWins: json['home_series_wins'] as int? ?? 0,
      awaySeriesWins: json['away_series_wins'] as int? ?? 0,
      prediction: predData != null ? PlayoffPrediction.fromJson(predData) : null,
      context: json['context'] as Map<String, dynamic>?,
    );
  }
}

// ============================================================================
// Full Series Detail (series screen)
// ============================================================================

class PlayoffSeriesDetail {
  final PlayoffSeriesInfo info;
  final List<PlayoffSeriesGame> gameHistory;
  final PlayoffGame? nextGamePrediction;

  const PlayoffSeriesDetail({
    required this.info,
    required this.gameHistory,
    this.nextGamePrediction,
  });

  factory PlayoffSeriesDetail.fromJson(Map<String, dynamic> json) {
    final history = (json['game_history'] as List<dynamic>? ?? [])
        .map((g) => PlayoffSeriesGame.fromJson(g as Map<String, dynamic>))
        .toList();
    final nextData = json['next_game_prediction'] as Map<String, dynamic>?;

    return PlayoffSeriesDetail(
      info: PlayoffSeriesInfo.fromJson(json),
      gameHistory: history,
      nextGamePrediction: nextData != null ? PlayoffGame.fromJson(nextData) : null,
    );
  }
}
