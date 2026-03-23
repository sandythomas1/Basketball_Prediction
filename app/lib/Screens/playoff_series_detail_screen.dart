import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../Models/playoff_models.dart';
import '../Providers/playoff_provider.dart';
import '../theme/app_theme.dart';

/// Detailed view of a single playoff series.
/// Shows the series score, game history, and next game prediction.
class PlayoffSeriesDetailScreen extends ConsumerWidget {
  final String seriesId;

  const PlayoffSeriesDetailScreen({super.key, required this.seriesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(playoffSeriesProvider(seriesId));

    return Scaffold(
      backgroundColor: context.bgPrimary,
      appBar: AppBar(
        backgroundColor: context.bgSecondary,
        title: Text(
          'Series Detail',
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: context.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: context.bgCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: detailAsync.isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.textSecondary,
                      ),
                    )
                  : Icon(Icons.refresh, color: context.textSecondary),
              onPressed: detailAsync.isLoading
                  ? null
                  : () => ref.read(playoffSeriesProvider(seriesId).notifier).refresh(),
            ),
          ),
        ],
      ),
      body: detailAsync.when(
        data: (detail) {
          if (detail == null) {
            return Center(
              child: Text(
                'Series not found',
                style: GoogleFonts.dmSans(color: context.textSecondary),
              ),
            );
          }
          return _SeriesDetailBody(detail: detail);
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: AppColors.accentOrange),
        ),
        error: (e, _) => Center(
          child: Text(
            'Failed to load series',
            style: GoogleFonts.dmSans(color: context.textSecondary),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Body
// =============================================================================

class _SeriesDetailBody extends StatelessWidget {
  final PlayoffSeriesDetail detail;

  const _SeriesDetailBody({required this.detail});

  @override
  Widget build(BuildContext context) {
    final info = detail.info;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Series header card
        _SeriesHeaderCard(info: info),
        const SizedBox(height: 16),

        // Next game prediction (if series not complete)
        if (!info.isComplete && detail.nextGamePrediction != null) ...[
          _SectionLabel(label: 'Next Game Prediction'),
          _NextGameCard(game: detail.nextGamePrediction!),
          const SizedBox(height: 16),
        ],

        // Game history
        if (detail.gameHistory.isNotEmpty) ...[
          _SectionLabel(label: 'Game History'),
          ...detail.gameHistory.map((g) => _GameHistoryRow(
                game: g,
                higherSeedId: info.higherSeedId,
                higherSeedName: info.higherSeedName,
                lowerSeedName: info.lowerSeedName,
              )),
        ],
      ],
    );
  }
}

// =============================================================================
// Section label
// =============================================================================

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: context.textSecondary,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// =============================================================================
// Series header card
// =============================================================================

class _SeriesHeaderCard extends StatelessWidget {
  final PlayoffSeriesInfo info;

  const _SeriesHeaderCard({required this.info});

  @override
  Widget build(BuildContext context) {
    final higherName = info.higherSeedName.split(' ').last;
    final lowerName = info.lowerSeedName.split(' ').last;
    final isComplete = info.isComplete;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: [
          // Round + conference label
          Text(
            _formatRound(info.roundName) +
                (info.conference.isNotEmpty && info.conference.toLowerCase() != 'finals'
                    ? ' · ${info.conference}'
                    : ''),
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: context.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),

          // Teams and score
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ScoreTeam(
                name: higherName,
                wins: info.higherSeedWins,
                isWinner: isComplete && info.winnerId == info.higherSeedId,
                isLeading: info.higherSeedWins > info.lowerSeedWins,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${info.higherSeedWins} – ${info.lowerSeedWins}',
                  style: GoogleFonts.dmSans(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
              ),
              _ScoreTeam(
                name: lowerName,
                wins: info.lowerSeedWins,
                isWinner: isComplete && info.winnerId == info.lowerSeedId,
                isLeading: info.lowerSeedWins > info.higherSeedWins,
                alignRight: true,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Context string
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: context.bgPrimary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              info.seriesContext,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: isComplete ? AppColors.accentOrange : context.textSecondary,
                fontWeight: isComplete ? FontWeight.w600 : FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  String _formatRound(String name) {
    switch (name.toLowerCase()) {
      case 'first_round':
        return 'First Round';
      case 'conf_semifinals':
        return 'Conference Semifinals';
      case 'conf_finals':
        return 'Conference Finals';
      case 'finals':
        return 'NBA Finals';
      default:
        return name.replaceAll('_', ' ');
    }
  }
}

class _ScoreTeam extends StatelessWidget {
  final String name;
  final int wins;
  final bool isWinner;
  final bool isLeading;
  final bool alignRight;

  const _ScoreTeam({
    required this.name,
    required this.wins,
    this.isWinner = false,
    this.isLeading = false,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      child: Text(
        name,
        style: GoogleFonts.dmSans(
          fontSize: 15,
          fontWeight: isLeading || isWinner ? FontWeight.w700 : FontWeight.w500,
          color: isWinner ? AppColors.accentOrange : context.textPrimary,
        ),
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// =============================================================================
// Next game prediction card
// =============================================================================

class _NextGameCard extends StatelessWidget {
  final PlayoffGame game;

  const _NextGameCard({required this.game});

  @override
  Widget build(BuildContext context) {
    final pred = game.prediction;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.accentOrange.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Game number badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accentOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.accentOrange.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  'Game ${game.gameNumber}',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentOrange,
                  ),
                ),
              ),
              if (game.gameTime != null) ...[
                const SizedBox(width: 8),
                Text(
                  game.gameTime!,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),

          // Teams + probabilities
          Row(
            children: [
              Expanded(
                child: _PredTeam(
                  name: game.awayTeam,
                  prob: pred?.awayWinProb,
                  isFavored: pred?.favored == 'away',
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '@',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: context.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: _PredTeam(
                  name: game.homeTeam,
                  prob: pred?.homeWinProb,
                  isFavored: pred?.favored == 'home',
                  alignRight: true,
                ),
              ),
            ],
          ),

          if (pred != null) ...[
            const SizedBox(height: 12),
            // Probability bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 6,
                child: Row(
                  children: [
                    Expanded(
                      flex: (pred.awayWinProb * 100).round(),
                      child: Container(
                        color: pred.awayWinProb > pred.homeWinProb
                            ? AppColors.accentOrange
                            : context.borderColor,
                      ),
                    ),
                    Expanded(
                      flex: (pred.homeWinProb * 100).round(),
                      child: Container(
                        color: pred.homeWinProb >= pred.awayWinProb
                            ? AppColors.accentOrange
                            : context.borderColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Series win probabilities
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Series: ${(pred.seriesWinProbAway * 100).round()}%',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: context.textSecondary,
                  ),
                ),
                Text(
                  pred.confidence,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: context.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Series: ${(pred.seriesWinProbHome * 100).round()}%',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PredTeam extends StatelessWidget {
  final String name;
  final double? prob;
  final bool isFavored;
  final bool alignRight;

  const _PredTeam({
    required this.name,
    this.prob,
    this.isFavored = false,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    final shortName = name.split(' ').last;
    return Column(
      crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          shortName,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        if (prob != null)
          Text(
            '${(prob! * 100).round()}%',
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isFavored ? AppColors.accentOrange : context.textSecondary,
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// Game history row
// =============================================================================

class _GameHistoryRow extends StatelessWidget {
  final PlayoffSeriesGame game;
  final int higherSeedId;
  final String higherSeedName;
  final String lowerSeedName;

  const _GameHistoryRow({
    required this.game,
    required this.higherSeedId,
    required this.higherSeedName,
    required this.lowerSeedName,
  });

  @override
  Widget build(BuildContext context) {
    final homeIsHigher = game.homeTeamId == higherSeedId;
    final homeName = homeIsHigher ? higherSeedName : lowerSeedName;
    final awayName = homeIsHigher ? lowerSeedName : higherSeedName;
    final homeShort = homeName.split(' ').last;
    final awayShort = awayName.split(' ').last;

    final homeWon = game.winnerId != null && game.winnerId == game.homeTeamId;
    final awayWon = game.winnerId != null && game.winnerId == game.awayTeamId;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          // Game number
          SizedBox(
            width: 50,
            child: Text(
              'Game ${game.gameNumber}',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: context.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Away team
          Expanded(
            child: Text(
              awayShort,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: awayWon ? FontWeight.w700 : FontWeight.w500,
                color: awayWon ? context.textPrimary : context.textSecondary,
              ),
            ),
          ),

          // Score or status
          if (game.isFinal && game.awayScore != null && game.homeScore != null)
            Row(
              children: [
                Text(
                  '${game.awayScore}',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: awayWon ? FontWeight.w700 : FontWeight.w400,
                    color: awayWon ? context.textPrimary : context.textSecondary,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '–',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: context.textSecondary,
                    ),
                  ),
                ),
                Text(
                  '${game.homeScore}',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: homeWon ? FontWeight.w700 : FontWeight.w400,
                    color: homeWon ? context.textPrimary : context.textSecondary,
                  ),
                ),
              ],
            )
          else
            Text(
              'Scheduled',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: context.textSecondary,
              ),
            ),

          // Home team
          Expanded(
            child: Text(
              homeShort,
              textAlign: TextAlign.right,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: homeWon ? FontWeight.w700 : FontWeight.w500,
                color: homeWon ? context.textPrimary : context.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
