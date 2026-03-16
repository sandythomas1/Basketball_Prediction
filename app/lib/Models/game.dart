/// Per-category game leader surfaced by the ESPN scoreboard API.
class GameLeader {
  final String category; // "points", "rebounds", "assists"
  final String playerName;
  final String displayValue; // e.g. "32 PTS, 8 REB, 7 AST"
  final bool isHome;

  const GameLeader({
    required this.category,
    required this.playerName,
    required this.displayValue,
    required this.isHome,
  });
}

/// Game model with prediction data
class Game {
  final String id;
  final String homeTeam;
  final String awayTeam;
  final String date;
  final String time;
  final String status;
  final String homeScore;
  final String awayScore;

  // Prediction fields
  final double? homeWinProb;
  final double? awayWinProb;
  final String? confidenceTier;
  final String? favoredTeam;
  final double? homeElo;
  final double? awayElo;

  // Game-specific confidence metrics
  final int? confidenceScore;
  final String? confidenceQualifier;
  final Map<String, dynamic>? confidenceFactors;

  // Injury information
  final List<String>? homeInjuries;
  final List<String>? awayInjuries;
  final String? injuryAdvantage;

  // Boxscore — quarter-by-quarter linescores from ESPN
  final List<int>? homeQuarters;
  final List<int>? awayQuarters;
  final List<GameLeader>? leaders;

  Game({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    required this.date,
    required this.time,
    required this.status,
    this.homeScore = '',
    this.awayScore = '',
    this.homeWinProb,
    this.awayWinProb,
    this.confidenceTier,
    this.favoredTeam,
    this.homeElo,
    this.awayElo,
    this.confidenceScore,
    this.confidenceQualifier,
    this.confidenceFactors,
    this.homeInjuries,
    this.awayInjuries,
    this.injuryAdvantage,
    this.homeQuarters,
    this.awayQuarters,
    this.leaders,
  });

  double get favoredProb {
    if (homeWinProb == null) return 0.5;
    return homeWinProb! >= 0.5 ? homeWinProb! : (1 - homeWinProb!);
  }

  bool get isHomeFavored {
    if (homeWinProb == null) return true;
    return homeWinProb! >= 0.5;
  }

  bool get isLive {
    final statusLower = status.toLowerCase();
    return statusLower.contains('progress') ||
        statusLower.contains('halftime') ||
        statusLower.contains('q1') ||
        statusLower.contains('q2') ||
        statusLower.contains('q3') ||
        statusLower.contains('q4') ||
        statusLower.contains('ot');
  }

  bool get isFinal => status.toLowerCase() == 'final';

  bool get isScheduled => status.toLowerCase() == 'scheduled';

  bool get hasInjuries {
    return (homeInjuries != null && homeInjuries!.isNotEmpty) ||
        (awayInjuries != null && awayInjuries!.isNotEmpty);
  }

  bool get hasBoxScore =>
      homeQuarters != null &&
      awayQuarters != null &&
      homeQuarters!.isNotEmpty;

  /// Quarter header labels matching the length of linescores.
  List<String> get quarterLabels {
    final count = homeQuarters?.length ?? 0;
    if (count <= 4) {
      return List.generate(count, (i) => 'Q${i + 1}');
    }
    return [
      'Q1', 'Q2', 'Q3', 'Q4',
      ...List.generate(count - 4, (i) => 'OT${i + 1}'),
    ];
  }

  Game copyWith({
    String? id,
    String? homeTeam,
    String? awayTeam,
    String? date,
    String? time,
    String? status,
    String? homeScore,
    String? awayScore,
    double? homeWinProb,
    double? awayWinProb,
    String? confidenceTier,
    String? favoredTeam,
    double? homeElo,
    double? awayElo,
    int? confidenceScore,
    String? confidenceQualifier,
    Map<String, dynamic>? confidenceFactors,
    List<String>? homeInjuries,
    List<String>? awayInjuries,
    String? injuryAdvantage,
    List<int>? homeQuarters,
    List<int>? awayQuarters,
    List<GameLeader>? leaders,
  }) {
    return Game(
      id: id ?? this.id,
      homeTeam: homeTeam ?? this.homeTeam,
      awayTeam: awayTeam ?? this.awayTeam,
      date: date ?? this.date,
      time: time ?? this.time,
      status: status ?? this.status,
      homeScore: homeScore ?? this.homeScore,
      awayScore: awayScore ?? this.awayScore,
      homeWinProb: homeWinProb ?? this.homeWinProb,
      awayWinProb: awayWinProb ?? this.awayWinProb,
      confidenceTier: confidenceTier ?? this.confidenceTier,
      favoredTeam: favoredTeam ?? this.favoredTeam,
      homeElo: homeElo ?? this.homeElo,
      awayElo: awayElo ?? this.awayElo,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      confidenceQualifier: confidenceQualifier ?? this.confidenceQualifier,
      confidenceFactors: confidenceFactors ?? this.confidenceFactors,
      homeInjuries: homeInjuries ?? this.homeInjuries,
      awayInjuries: awayInjuries ?? this.awayInjuries,
      injuryAdvantage: injuryAdvantage ?? this.injuryAdvantage,
      homeQuarters: homeQuarters ?? this.homeQuarters,
      awayQuarters: awayQuarters ?? this.awayQuarters,
      leaders: leaders ?? this.leaders,
    );
  }
}

