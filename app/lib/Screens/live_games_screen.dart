import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../Models/game.dart';
import '../Providers/games_provider.dart';
import '../Widgets/team_logo.dart';
import '../theme/app_theme.dart';
import '../Providers/league_provider.dart';

class LiveGamesScreen extends ConsumerWidget {
  const LiveGamesScreen({super.key});

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
            'Live Games',
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
        data: (state) =>
            _buildGamesList(context, ref, state.liveGames, state.isRefreshing),
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
              'No games in progress',
              style: GoogleFonts.dmSans(fontSize: 16, color: context.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Check the Today tab for upcoming games',
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
          if (index == 0) {
            return _SectionHeader(count: games.length);
          }
          return _LiveGameCard(game: games[index - 1]);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final int count;
  const _SectionHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            'IN PROGRESS',
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
              color: AppColors.liveRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$count live',
              style: GoogleFonts.spaceMono(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: AppColors.liveRed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Live game card — always shows quarter scores when available
// ---------------------------------------------------------------------------

class _LiveGameCard extends StatelessWidget {
  final Game game;
  const _LiveGameCard({required this.game});

  @override
  Widget build(BuildContext context) {
    final homeScore = int.tryParse(game.homeScore) ?? 0;
    final awayScore = int.tryParse(game.awayScore) ?? 0;
    final homeWinning = homeScore > awayScore;
    final awayWinning = awayScore > homeScore;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: const Border(
            left: BorderSide(color: AppColors.liveRed, width: 3),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Team scores
                  _TeamScoreRow(
                    team: game.homeTeam,
                    score: game.homeScore,
                    isWinning: homeWinning,
                    isAway: false,
                  ),
                  const SizedBox(height: 8),
                  _TeamScoreRow(
                    team: game.awayTeam,
                    score: game.awayScore,
                    isWinning: awayWinning,
                    isAway: true,
                  ),
                  const SizedBox(height: 12),

                  // Status footer
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
                          game.status,
                          style: GoogleFonts.spaceMono(
                            fontSize: 12,
                            color: context.textSecondary,
                          ),
                        ),
                        _LiveBadge(),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Quarter scores — always visible for live games
            if (game.hasBoxScore) _LiveQuarterStrip(game: game),

            // Leaders
            if (game.leaders != null && game.leaders!.isNotEmpty)
              _LiveLeadersStrip(game: game),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Live quarter score strip
// ---------------------------------------------------------------------------

class _LiveQuarterStrip extends StatelessWidget {
  final Game game;
  const _LiveQuarterStrip({required this.game});

  @override
  Widget build(BuildContext context) {
    final labels = game.quarterLabels;
    final homeQ = game.homeQuarters ?? [];
    final awayQ = game.awayQuarters ?? [];
    final homeTotal = int.tryParse(game.homeScore) ?? 0;
    final awayTotal = int.tryParse(game.awayScore) ?? 0;
    final homeLeading = homeTotal > awayTotal;

    return Container(
      decoration: BoxDecoration(
        color: context.bgSecondary,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Table(
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
          // Home
          TableRow(
            children: [
              _teamCell(context, game.homeTeam, bold: homeLeading),
              ...List.generate(labels.length, (i) {
                final val = i < homeQ.length ? homeQ[i].toString() : '-';
                final isCurrent = i == homeQ.length - 1 && !game.isFinal;
                return _cell(context, val,
                    bold: homeLeading, highlight: isCurrent);
              }),
              _cell(context, homeTotal.toString(),
                  bold: homeLeading, accent: homeLeading),
            ],
          ),
          // Away
          TableRow(
            children: [
              _teamCell(context, game.awayTeam, bold: !homeLeading),
              ...List.generate(labels.length, (i) {
                final val = i < awayQ.length ? awayQ[i].toString() : '-';
                final isCurrent = i == awayQ.length - 1 && !game.isFinal;
                return _cell(context, val,
                    bold: !homeLeading, highlight: isCurrent);
              }),
              _cell(context, awayTotal.toString(),
                  bold: !homeLeading, accent: !homeLeading),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    String text, {
    bool isHeader = false,
    bool bold = false,
    bool accent = false,
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.spaceMono(
          fontSize: 12,
          fontWeight: isHeader || bold ? FontWeight.w600 : FontWeight.w400,
          color: isHeader
              ? context.textMuted
              : accent
                  ? AppColors.accentGreen
                  : highlight
                      ? AppColors.liveRed
                      : context.textPrimary,
        ),
      ),
    );
  }

  Widget _teamCell(BuildContext context, String teamName,
      {bool bold = false}) {
    final abbr = getEspnAbbreviation(teamName).toUpperCase();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
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
// Live leaders strip
// ---------------------------------------------------------------------------

class _LiveLeadersStrip extends StatelessWidget {
  final Game game;
  const _LiveLeadersStrip({required this.game});

  @override
  Widget build(BuildContext context) {
    final leaders = game.leaders ?? [];
    if (leaders.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: context.bgSecondary,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: context.borderColor, height: 1),
          const SizedBox(height: 8),
          Text(
            'LEADERS',
            style: GoogleFonts.spaceMono(
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: context.textMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: leaders.map((l) {
              final teamName = l.isHome ? game.homeTeam : game.awayTeam;
              final abbr = getEspnAbbreviation(teamName).toUpperCase();
              String catLabel;
              switch (l.category) {
                case 'points':
                  catLabel = 'PTS';
                  break;
                case 'rebounds':
                  catLabel = 'REB';
                  break;
                case 'assists':
                  catLabel = 'AST';
                  break;
                default:
                  catLabel = l.category.toUpperCase();
              }
              return Text(
                '$catLabel: ${l.playerName} ($abbr) ${l.displayValue}',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: context.textSecondary,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

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
        TeamLogo(teamName: team, size: 32, backgroundColor: context.bgSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            isAway ? '@ $team' : team,
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: isWinning ? FontWeight.w600 : FontWeight.w500,
              color: context.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          score.isEmpty ? '-' : score,
          style: GoogleFonts.spaceMono(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isWinning ? AppColors.accentGreen : context.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _LiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.liveRed.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingDot(),
          const SizedBox(width: 6),
          Text(
            'LIVE',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.liveRed,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.liveRed,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
