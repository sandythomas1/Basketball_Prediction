import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../Models/game.dart';
import '../Providers/games_provider.dart';
import '../Widgets/team_logo.dart';

/// Screen showing live (in-progress) games with scores
class LiveGamesScreen extends ConsumerWidget {
  const LiveGamesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamesAsync = ref.watch(gamesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Games'),
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
        data: (state) => _buildGamesList(context, ref, state.liveGames, state.isRefreshing),
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
              'No games in progress',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Check the Today tab for upcoming games',
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
            return _SectionHeader(
              title: 'IN PROGRESS',
              count: games.length,
              isLive: true,
            );
          }
          final game = games[index - 1];
          return _LiveGameCard(game: game);
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final bool isLive;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.isLive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          if (isLive) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.5),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isLive ? Colors.red : Colors.grey[500],
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
              color: isLive
                  ? Colors.red.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$count ${count == 1 ? 'game' : 'games'}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isLive ? Colors.red : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveGameCard extends StatelessWidget {
  final Game game;

  const _LiveGameCard({required this.game});

  @override
  Widget build(BuildContext context) {
    final isLive = game.isLive;
    final homeScore = int.tryParse(game.homeScore) ?? 0;
    final awayScore = int.tryParse(game.awayScore) ?? 0;
    final homeWinning = homeScore > awayScore;
    final awayWinning = awayScore > homeScore;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isLive ? Colors.red.withOpacity(0.3) : Colors.grey[200]!,
          width: isLive ? 2 : 1,
        ),
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
                        isWinning: awayWinning,
                        isAway: true,
                      ),
                      const SizedBox(height: 8),
                      _TeamScoreRow(
                        team: game.homeTeam,
                        score: game.homeScore,
                        isWinning: homeWinning,
                        isAway: false,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Footer with status
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
                    color: isLive
                        ? Colors.red.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLive) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        game.status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isLive ? Colors.red : Colors.grey[600],
                        ),
                      ),
                    ],
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
  final bool isWinning;
  final bool isAway;

  const _TeamScoreRow({
    required this.team,
    required this.score,
    required this.isWinning,
    required this.isAway,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TeamLogo(
          teamName: team,
          size: 32,
          backgroundColor: Colors.grey[100],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            isAway ? team : '@ $team',
            style: TextStyle(
              fontSize: 15,
              fontWeight: isWinning ? FontWeight.w600 : FontWeight.w500,
              color: isWinning ? Colors.black : Colors.grey[700],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          score.isEmpty ? '-' : score,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isWinning ? Colors.green[700] : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
