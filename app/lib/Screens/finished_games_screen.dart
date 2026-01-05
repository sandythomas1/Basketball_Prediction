import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../Models/game.dart';
import '../Providers/games_provider.dart';
import '../Widgets/team_logo.dart';

/// Screen showing finished games with final scores
class FinishedGamesScreen extends ConsumerWidget {
  const FinishedGamesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamesAsync = ref.watch(gamesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finished Games'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: gamesAsync.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: gamesAsync.isLoading
                ? null
                : () => _onRefresh(context, ref),
          ),
        ],
      ),
      body: gamesAsync.when(
        data: (state) => _buildGamesList(context, ref, state.finishedGames, state.isRefreshing),
        loading: () => const Center(child: CircularProgressIndicator()),
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
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
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
              Icons.sports_basketball_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No finished games yet',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Completed games will appear here',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _onRefresh(context, ref),
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
            color: Colors.grey[500],
          ),
          const SizedBox(width: 8),
          Text(
            'FINAL SCORES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.grey[300],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$gameCount ${gameCount == 1 ? 'game' : 'games'}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
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
                        team: game.awayTeam,
                        score: game.awayScore,
                        isWinner: awayWon,
                        isAway: true,
                      ),
                      const SizedBox(height: 10),
                      _TeamScoreRow(
                        team: game.homeTeam,
                        score: game.homeScore,
                        isWinner: homeWon,
                        isAway: false,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Footer with date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  game.date,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Final',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
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
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: isWinner ? Border.all(color: Colors.green[200]!) : null,
          ),
          child: TeamLogo(
            teamName: team,
            size: 32,
            backgroundColor: isWinner ? Colors.green[50] : Colors.grey[100],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isAway ? team : '@ $team',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isWinner ? FontWeight.w600 : FontWeight.w500,
                    color: isWinner ? Colors.black : Colors.grey[700],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isWinner) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.emoji_events,
                  size: 16,
                  color: Colors.amber[600],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          score.isEmpty ? '-' : score,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: isWinner ? Colors.green[700] : Colors.grey[500],
          ),
        ),
      ],
    );
  }
}
