import 'package:flutter/material.dart';
import 'package:pie_chart/pie_chart.dart';
import '../Models/game.dart';
import '../Widgets/team_logo.dart';

/// Detailed game screen with prediction visualization
class GameDetailScreen extends StatelessWidget {
  final Game game;

  const GameDetailScreen({
    super.key,
    required this.game,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Prediction'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Matchup Header
            _MatchupHeader(game: game),
            const SizedBox(height: 24),
            // Prediction Card
            _PredictionCard(game: game),
            const SizedBox(height: 16),
            // Elo Ratings Card
            _EloCard(game: game),
            const SizedBox(height: 16),
            // Game Context Card
            _ContextCard(game: game),
          ],
        ),
      ),
    );
  }
}

/// Matchup header showing both teams
class _MatchupHeader extends StatelessWidget {
  final Game game;

  const _MatchupHeader({required this.game});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${game.date} • ${game.time}',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _TeamBadge(team: game.awayTeam),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'VS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            _TeamBadge(team: game.homeTeam),
          ],
        ),
      ],
    );
  }
}

class _TeamBadge extends StatelessWidget {
  final String team;

  const _TeamBadge({required this.team});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: TeamLogoLarge(
            teamName: team,
            size: 56,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 80,
          child: Text(
            team.split(' ').last, // Just the team name (e.g., "Lakers")
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Prediction card with confidence tier and pie chart
class _PredictionCard extends StatelessWidget {
  final Game game;

  const _PredictionCard({required this.game});

  Color _getTierColor(String? tier) {
    switch (tier?.toLowerCase()) {
      case 'strong favorite':
        return Colors.green[700]!;
      case 'moderate favorite':
        return Colors.green[500]!;
      case 'lean favorite':
        return Colors.orange[600]!;
      case 'toss-up':
        return Colors.purple[500]!;
      case 'lean underdog':
        return Colors.orange[700]!;
      case 'moderate underdog':
        return Colors.red[400]!;
      case 'strong underdog':
        return Colors.red[700]!;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeProb = game.homeWinProb ?? 0.5;
    final awayProb = 1 - homeProb;
    final favoredTeam = game.favoredTeam ?? game.homeTeam;
    final favoredProb = game.favoredProb * 100;
    final tier = game.confidenceTier ?? 'Toss-Up';
    final tierColor = _getTierColor(tier);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section title
            Text(
              'MODEL PREDICTION',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            // Confidence tier badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: tierColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: tierColor.withOpacity(0.3)),
              ),
              child: Text(
                tier,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: tierColor,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Pie Chart
            Center(
              child: SizedBox(
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      dataMap: {
                        game.homeTeam: homeProb * 100,
                        game.awayTeam: awayProb * 100,
                      },
                      chartType: ChartType.ring,
                      ringStrokeWidth: 24,
                      colorList: [
                        game.isHomeFavored ? Colors.green[500]! : Colors.grey[400]!,
                        !game.isHomeFavored ? Colors.green[500]! : Colors.grey[400]!,
                      ],
                      chartValuesOptions: const ChartValuesOptions(
                        showChartValues: false,
                      ),
                      legendOptions: const LegendOptions(
                        showLegends: false,
                      ),
                      chartRadius: 90,
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${favoredProb.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.green[700],
                          ),
                        ),
                        Text(
                          _getShortName(favoredTeam),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Prediction details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _DetailRow(
                    label: 'Favored Team',
                    value: favoredTeam,
                    valueColor: Colors.green[700],
                  ),
                  const Divider(height: 20),
                  _DetailRow(
                    label: 'Win Probability',
                    value: '${favoredProb.toStringAsFixed(1)}%',
                  ),
                  const Divider(height: 20),
                  _DetailRow(
                    label: 'Confidence',
                    value: tier,
                    valueColor: tierColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getShortName(String teamName) {
    final words = teamName.split(' ');
    return words.last;
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Elo ratings comparison card
class _EloCard extends StatelessWidget {
  final Game game;

  const _EloCard({required this.game});

  @override
  Widget build(BuildContext context) {
    final homeElo = game.homeElo ?? 1500;
    final awayElo = game.awayElo ?? 1500;
    final homeHigher = homeElo >= awayElo;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ELO RATINGS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _EloTeam(
                  team: game.awayTeam,
                  elo: awayElo,
                  isHigher: !homeHigher,
                ),
                Text(
                  'vs',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
                _EloTeam(
                  team: game.homeTeam,
                  elo: homeElo,
                  isHigher: homeHigher,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EloTeam extends StatelessWidget {
  final String team;
  final double elo;
  final bool isHigher;

  const _EloTeam({
    required this.team,
    required this.elo,
    required this.isHigher,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          _getAbbreviation(team),
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          elo.toInt().toString(),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: isHigher ? Colors.green[700] : Colors.grey[500],
          ),
        ),
      ],
    );
  }

  String _getAbbreviation(String teamName) {
    final words = teamName.split(' ');
    if (words.length >= 2) {
      return words.last.substring(0, 3).toUpperCase();
    }
    return teamName.substring(0, 3).toUpperCase();
  }
}

/// Additional game context card
class _ContextCard extends StatelessWidget {
  final Game game;

  const _ContextCard({required this.game});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GAME CONTEXT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _DetailRow(
                    label: 'Game Time',
                    value: game.time,
                  ),
                  const Divider(height: 20),
                  _DetailRow(
                    label: 'Home Team',
                    value: game.homeTeam,
                  ),
                  const Divider(height: 20),
                  _DetailRow(
                    label: 'Away Team',
                    value: game.awayTeam,
                  ),
                  const Divider(height: 20),
                  _DetailRow(
                    label: 'Status',
                    value: game.status,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
