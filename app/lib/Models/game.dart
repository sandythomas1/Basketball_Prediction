/// Game model with prediction data
class Game {
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

  Game({
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
  });

  /// Get the favored team's win probability
  double get favoredProb {
    if (homeWinProb == null) return 0.5;
    return homeWinProb! >= 0.5 ? homeWinProb! : (1 - homeWinProb!);
  }

  /// Check if home team is favored
  bool get isHomeFavored {
    if (homeWinProb == null) return true;
    return homeWinProb! >= 0.5;
  }

  /// Check if the game is live (in progress)
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

  /// Check if the game is final
  bool get isFinal {
    return status.toLowerCase() == 'final';
  }

  /// Check if the game is scheduled (not started)
  bool get isScheduled {
    return status.toLowerCase() == 'scheduled';
  }

  /// Copy with new values
  Game copyWith({
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
  }) {
    return Game(
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
    );
  }
}

