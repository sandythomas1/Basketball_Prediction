import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../Models/game.dart';
import '../Providers/games_provider.dart';
import '../Widgets/team_logo.dart';
import '../theme/app_theme.dart';
import '../Providers/league_provider.dart';
import 'game_detail_screen.dart';

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
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: context.bgCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: ref.watch(leagueProvider),
                icon: Icon(Icons.keyboard_arrow_down, color: context.textSecondary, size: 20),
                dropdownColor: context.bgCard,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
                onChanged: (String? newValue) {
                  if (newValue != null && newValue != ref.read(leagueProvider)) {
                    ref.read(leagueProvider.notifier).state = newValue;
                    ref.read(gamesProvider.notifier).refresh();
                  }
                },
                items: const [
                  DropdownMenuItem(value: 'nba', child: Text('NBA')),
                  DropdownMenuItem(value: 'wnba', child: Text('WNBA')),
                ],
              ),
            ),
          ),
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
          Icon(Icons.error_outline, size: 48, color: AppColors.errorRed),
          const SizedBox(height: 16),
          Text(
            error,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 16, color: context.textSecondary),
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
            Icon(Icons.sports_outlined, size: 48, color: context.textMuted),
            const SizedBox(height: 16),
            Text(
              'No finished games yet',
              style: GoogleFonts.dmSans(fontSize: 16, color: context.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Completed games will appear here',
              style: GoogleFonts.dmSans(fontSize: 14, color: context.textMuted),
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
        itemCount: games.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _buildHeader(context, games.length);
          return _FinishedGameCard(game: games[index - 1]);
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int gameCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 14, color: context.textMuted),
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
              color: context.textMuted.withValues(alpha: 0.1),
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

// ---------------------------------------------------------------------------
// Finished game card with expandable boxscore
// ---------------------------------------------------------------------------

class _FinishedGameCard extends StatefulWidget {
  final Game game;
  const _FinishedGameCard({required this.game});

  @override
  State<_FinishedGameCard> createState() => _FinishedGameCardState();
}

class _FinishedGameCardState extends State<_FinishedGameCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final homeScore = int.tryParse(game.homeScore) ?? 0;
    final awayScore = int.tryParse(game.awayScore) ?? 0;
    final homeWon = homeScore > awayScore;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => GameDetailScreen(game: game)),
          ),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
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
                      isWinner: !homeWon && awayScore != homeScore,
                      isAway: true,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: context.borderColor)),
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
                          Row(
                            children: [
                              if (game.hasBoxScore) ...[
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => setState(() => _expanded = !_expanded),
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Icon(
                                      _expanded ? Icons.expand_less : Icons.expand_more,
                                      size: 18,
                                      color: context.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: context.textMuted.withValues(alpha: 0.15),
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: game.hasBoxScore
                    ? _BoxScoreSection(game: game)
                    : const SizedBox.shrink(),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Boxscore section (quarter table + leaders)
// ---------------------------------------------------------------------------

class _BoxScoreSection extends StatelessWidget {
  final Game game;
  const _BoxScoreSection({required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.bgSecondary,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: context.borderColor, height: 1),
          const SizedBox(height: 12),

          // Quarter-by-quarter table
          _QuarterTable(game: game),

          // Game leaders
          if (game.leaders != null && game.leaders!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'GAME LEADERS',
              style: GoogleFonts.spaceMono(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: context.textMuted,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            ...game.leaders!.map((l) => _LeaderRow(leader: l, game: game)),
          ],
        ],
      ),
    );
  }
}

class _QuarterTable extends StatelessWidget {
  final Game game;
  const _QuarterTable({required this.game});

  @override
  Widget build(BuildContext context) {
    final labels = game.quarterLabels;
    final homeQ = game.homeQuarters ?? [];
    final awayQ = game.awayQuarters ?? [];
    final homeTotal = int.tryParse(game.homeScore) ?? 0;
    final awayTotal = int.tryParse(game.awayScore) ?? 0;
    final homeWon = homeTotal > awayTotal;

    return Table(
      columnWidths: {
        0: const FlexColumnWidth(2.2),
        for (int i = 0; i < labels.length; i++)
          i + 1: const FlexColumnWidth(1),
        labels.length + 1: const FlexColumnWidth(1.2),
      },
      children: [
        // Header
        TableRow(
          children: [
            _cell(context, '', isHeader: true),
            ...labels.map((l) => _cell(context, l, isHeader: true)),
            _cell(context, 'T', isHeader: true),
          ],
        ),
        // Home row
        TableRow(
          children: [
            _teamCell(context, game.homeTeam, bold: homeWon),
            ...List.generate(labels.length, (i) {
              final val = i < homeQ.length ? homeQ[i].toString() : '-';
              return _cell(context, val, bold: homeWon);
            }),
            _cell(context, homeTotal.toString(),
                bold: homeWon, accent: homeWon),
          ],
        ),
        // Away row
        TableRow(
          children: [
            _teamCell(context, game.awayTeam, bold: !homeWon),
            ...List.generate(labels.length, (i) {
              final val = i < awayQ.length ? awayQ[i].toString() : '-';
              return _cell(context, val, bold: !homeWon);
            }),
            _cell(context, awayTotal.toString(),
                bold: !homeWon, accent: !homeWon),
          ],
        ),
      ],
    );
  }

  Widget _cell(
    BuildContext context,
    String text, {
    bool isHeader = false,
    bool bold = false,
    bool accent = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.spaceMono(
          fontSize: 12,
          fontWeight:
              isHeader || bold ? FontWeight.w600 : FontWeight.w400,
          color: isHeader
              ? context.textMuted
              : accent
                  ? AppColors.accentGreen
                  : context.textPrimary,
        ),
      ),
    );
  }

  Widget _teamCell(BuildContext context, String teamName,
      {bool bold = false}) {
    final abbr =
        getEspnAbbreviation(teamName).toUpperCase();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          TeamLogo(teamName: teamName, size: 18, borderRadius: 4),
          const SizedBox(width: 6),
          Text(
            abbr,
            style: GoogleFonts.spaceMono(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Leader row
// ---------------------------------------------------------------------------

class _LeaderRow extends StatelessWidget {
  final GameLeader leader;
  final Game game;
  const _LeaderRow({required this.leader, required this.game});

  String get _categoryLabel {
    switch (leader.category) {
      case 'points':
        return 'PTS';
      case 'rebounds':
        return 'REB';
      case 'assists':
        return 'AST';
      default:
        return leader.category.toUpperCase();
    }
  }

  IconData get _categoryIcon {
    switch (leader.category) {
      case 'points':
        return Icons.sports_basketball;
      case 'rebounds':
        return Icons.swap_vert;
      case 'assists':
        return Icons.handshake_outlined;
      default:
        return Icons.star_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamName = leader.isHome ? game.homeTeam : game.awayTeam;
    final abbr =
        getEspnAbbreviation(teamName).toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: context.bgCard,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_categoryIcon, size: 14, color: context.textMuted),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 36,
            child: Text(
              _categoryLabel,
              style: GoogleFonts.spaceMono(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: context.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '${leader.playerName} ($abbr)',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            leader.displayValue,
            style: GoogleFonts.spaceMono(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Team + score row (reused from original)
// ---------------------------------------------------------------------------

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
          backgroundColor: isWinner
              ? AppColors.accentGreen.withValues(alpha: 0.1)
              : context.bgSecondary,
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
                Icon(Icons.emoji_events, size: 16, color: AppColors.accentYellow),
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
