import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../Models/game.dart';
import '../Providers/games_provider.dart';
import '../Widgets/team_logo.dart';
import '../theme/app_theme.dart';


/// Screen showing finished games with final scores
class FinishedGamesScreen extends ConsumerWidget {
  const FinishedGamesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamesAsync = ref.watch(gamesProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.bgSecondary,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppColors.accentOrange, AppColors.accentYellow],
          ).createShader(bounds),
          child: Text(
            'Finished Games',
            style: GoogleFonts.dmSans(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        centerTitle: false,
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
                  : () => _onRefresh(context, ref),
            ),
          ),
        ],
      ),
      body: gamesAsync.when(
        data: (state) => _buildGamesList(
            context, ref, state.finishedGames, state.isRefreshing),
        loading: () => Center(
          child: CircularProgressIndicator(color: AppColors.accentOrange),
        ),
        error: (error, _) => _buildError(context, ref, error.toString()),
      ),
    );
  }

  Future<void> _onRefresh(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(gamesProvider.notifier).refresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildError(BuildContext context, WidgetRef ref, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: AppColors.errorRed,
          ),
          const SizedBox(height: 16),
          Text(
            error,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 16,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.invalidate(gamesProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildGamesList(
    BuildContext context,
    WidgetRef ref,
    List<Game> games,
    bool isRefreshing,
  ) {
    if (games.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports_outlined,
              size: 48,
              color: context.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'No finished games yet',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Completed games will appear here',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: context.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _onRefresh(context, ref),
      color: AppColors.accentOrange,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: games.length + 1, // +1 for header
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildHeader(context, games.length);
          }
          final game = games[index - 1];
          return _FinishedGameCard(game: game);
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int gameCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 14,
            color: context.textMuted,
          ),
          const SizedBox(width: 8),
          Text(
            'FINAL',
            style: GoogleFonts.spaceMono(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: context.textSecondary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [context.borderColor, Colors.transparent],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: context.textMuted.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$gameCount ${gameCount == 1 ? 'game' : 'games'}',
              style: GoogleFonts.spaceMono(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: context.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinishedGameCard extends StatelessWidget {
  final Game game;

  const _FinishedGameCard({required this.game});

  @override
  Widget build(BuildContext context) {
    final homeScore = int.tryParse(game.homeScore) ?? 0;
    final awayScore = int.tryParse(game.awayScore) ?? 0;
    final homeWon = homeScore > awayScore;
    final awayWon = awayScore > homeScore;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Teams with scores
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TeamScoreRow(
                        team: game.homeTeam,
                        score: game.homeScore,
                        isWinner: homeWon,
                        isAway: false,
                      ),
                      const SizedBox(height: 10),
                      _TeamScoreRow(
                        team: game.awayTeam,
                        score: game.awayScore,
                        isWinner: awayWon,
                        isAway: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Footer with date
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: context.borderColor),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    game.date,
                    style: GoogleFonts.spaceMono(
                      fontSize: 12,
                      color: context.textSecondary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: context.textMuted.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'FINAL',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
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

class _TeamScoreRow extends StatelessWidget {
  final String team;
  final String score;
  final bool isWinner;
  final bool isAway;

  const _TeamScoreRow({
    required this.team,
    required this.score,
    required this.isWinner,
    required this.isAway,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TeamLogo(
          teamName: team,
          size: 32,
          backgroundColor:
              isWinner ? AppColors.accentGreen.withOpacity(0.1) : context.bgSecondary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isAway ? '@ $team' : team,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: isWinner ? FontWeight.w600 : FontWeight.w500,
                    color: context.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isWinner) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.emoji_events,
                  size: 16,
                  color: AppColors.accentYellow,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          score.isEmpty ? '-' : score,
          style: GoogleFonts.spaceMono(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isWinner ? AppColors.accentGreen : context.textSecondary,
          ),
        ),
      ],
    );
  }
}
