import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../Models/playoff_models.dart';
import '../Providers/playoff_provider.dart';
import '../Widgets/team_logo.dart';
import '../theme/app_theme.dart';

/// Screen showing today's playoff games with series context badges.
class PlayoffGamesTodayScreen extends ConsumerWidget {
  const PlayoffGamesTodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamesAsync = ref.watch(todayPlayoffGamesProvider);

    return Scaffold(
      backgroundColor: context.bgPrimary,
      appBar: AppBar(
        backgroundColor: context.bgSecondary,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppColors.accentOrange, AppColors.accentYellow],
          ).createShader(bounds),
          child: Text(
            'Playoff Predictions',
            style: GoogleFonts.dmSans(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: context.bgCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: gamesAsync.isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.textSecondary,
                      ),
                    )
                  : Icon(Icons.refresh, color: context.textSecondary),
              onPressed: gamesAsync.isLoading
                  ? null
                  : () => ref.read(todayPlayoffGamesProvider.notifier).refresh(),
            ),
          ),
        ],
      ),
      body: gamesAsync.when(
        data: (games) => games.isEmpty
            ? _buildEmpty(context)
            : _buildGamesList(context, games),
        loading: () =>
            Center(child: CircularProgressIndicator(color: AppColors.accentOrange)),
        error: (e, _) => Center(
          child: Text(
            'Failed to load playoff games',
            style: GoogleFonts.dmSans(color: context.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events_outlined, size: 56, color: context.textSecondary),
          const SizedBox(height: 16),
          Text(
            'No Playoff Games Today',
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check the bracket for the full schedule',
            style: GoogleFonts.dmSans(fontSize: 14, color: context.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildGamesList(BuildContext context, List<PlayoffGame> games) {
    return RefreshIndicator(
      color: AppColors.accentOrange,
      onRefresh: () async {},
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: games.length,
        itemBuilder: (context, i) => _PlayoffGameCard(game: games[i]),
      ),
    );
  }
}

// ============================================================================
// Playoff Game Card
// ============================================================================

class _PlayoffGameCard extends StatelessWidget {
  final PlayoffGame game;

  const _PlayoffGameCard({required this.game});

  @override
  Widget build(BuildContext context) {
    final pred = game.prediction;

    return GestureDetector(
      onTap: () {
        if (game.seriesId != null) {
          Navigator.pushNamed(
            context,
            '/playoff/series',
            arguments: game.seriesId,
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: context.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Series context badge
            _SeriesBadge(game: game),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  // Teams and time
                  Row(
                    children: [
                      Expanded(
                        child: _TeamColumn(
                          teamName: game.awayTeam,
                          prob: pred?.awayWinProb,
                          isFavored: pred?.favored == 'away',
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            game.gameTime ?? 'TBD',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'PT',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: _TeamColumn(
                          teamName: game.homeTeam,
                          prob: pred?.homeWinProb,
                          isFavored: pred?.favored == 'home',
                          isHome: true,
                        ),
                      ),
                    ],
                  ),

                  if (pred != null) ...[
                    const SizedBox(height: 12),
                    // Win probability bar
                    _ProbabilityBar(
                      homeProb: pred.homeWinProb,
                      awayProb: pred.awayWinProb,
                    ),
                    const SizedBox(height: 8),
                    // Confidence badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ConfidenceBadge(
                          tier: pred.confidence,
                          score: pred.confidenceScore,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeriesBadge extends StatelessWidget {
  final PlayoffGame game;

  const _SeriesBadge({required this.game});

  @override
  Widget build(BuildContext context) {
    final isElimination = game.isEliminationGame;
    final isCloseout = game.isHomeCloseout || game.isAwayCloseout;

    Color badgeColor;
    String badgeLabel;
    if (isElimination && !isCloseout) {
      badgeColor = AppColors.liveRed;
      badgeLabel = 'Elimination Game';
    } else if (isCloseout) {
      badgeColor = AppColors.accentOrange;
      badgeLabel = 'Closeout Game';
    } else {
      badgeColor = AppColors.accentBlue;
      badgeLabel = 'Game ${game.gameNumber}';
    }

    final ctx = game.prediction?.seriesContext ?? '';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: badgeColor.withOpacity(0.4)),
            ),
            child: Text(
              badgeLabel,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: badgeColor,
              ),
            ),
          ),
          if (ctx.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ctx,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: context.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TeamColumn extends StatelessWidget {
  final String teamName;
  final double? prob;
  final bool isFavored;
  final bool isHome;

  const _TeamColumn({
    required this.teamName,
    this.prob,
    this.isFavored = false,
    this.isHome = false,
  });

  @override
  Widget build(BuildContext context) {
    final shortName = teamName.split(' ').last;
    return Column(
      crossAxisAlignment: isHome ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        TeamLogo(teamName: teamName, size: 44),
        const SizedBox(height: 6),
        Text(
          shortName,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
          textAlign: isHome ? TextAlign.end : TextAlign.start,
        ),
        if (prob != null)
          Text(
            '${(prob! * 100).round()}%',
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isFavored ? AppColors.accentOrange : context.textSecondary,
            ),
          ),
      ],
    );
  }
}

class _ProbabilityBar extends StatelessWidget {
  final double homeProb;
  final double awayProb;

  const _ProbabilityBar({required this.homeProb, required this.awayProb});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 6,
        child: Row(
          children: [
            Expanded(
              flex: (awayProb * 100).round(),
              child: Container(
                color: awayProb > homeProb
                    ? AppColors.accentOrange
                    : context.borderColor,
              ),
            ),
            Expanded(
              flex: (homeProb * 100).round(),
              child: Container(
                color: homeProb >= awayProb
                    ? AppColors.accentOrange
                    : context.borderColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final String tier;
  final int? score;

  const _ConfidenceBadge({required this.tier, this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.bgPrimary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.borderColor),
      ),
      child: Text(
        score != null ? '$tier · $score' : tier,
        style: GoogleFonts.dmSans(
          fontSize: 11,
          color: context.textSecondary,
        ),
      ),
    );
  }
}
