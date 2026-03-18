import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pie_chart/pie_chart.dart';
import 'package:share_plus/share_plus.dart';
import '../Models/game.dart';
import '../Providers/subscription_provider.dart';
import '../Widgets/pro_locked_overlay.dart';
import '../Widgets/team_logo.dart';
import '../Widgets/ai_chat_widget.dart';
import '../theme/app_theme.dart';

import 'forums_discussions_screen.dart';
import 'pro_upgrade_screen.dart';

/// Detailed game screen with prediction visualization
class GameDetailScreen extends ConsumerWidget {
  final Game game;

  const GameDetailScreen({
    super.key,
    required this.game,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.bgSecondary,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Icon(
                  Icons.arrow_back,
                  size: 20,
                  color: AppColors.accentBlue,
                ),
                const SizedBox(width: 4),
                Text(
                  'Back',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: AppColors.accentBlue,
                  ),
                ),
              ],
            ),
          ),
        ),
        leadingWidth: 80,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: context.bgCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.forum_outlined, color: context.textSecondary),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ForumsDiscussionScreen(gameId: game.id),
                  ),
                );
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: context.bgCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.share, color: context.textSecondary),
              onPressed: () {
                final prob = (game.favoredProb * 100).toStringAsFixed(1);
                final favored = game.favoredTeam ?? game.homeTeam;
                final tier = game.confidenceTier ?? 'Toss-Up';
                final text = StringBuffer()
                  ..writeln('${game.awayTeam} @ ${game.homeTeam}')
                  ..writeln('${game.date} \u2022 ${game.time}')
                  ..writeln()
                  ..writeln('Signal Sports prediction:')
                  ..writeln('$favored $prob% ($tier)')
                  ..writeln()
                  ..write('Get predictions at signalsports.app');
                Share.share(text.toString());
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Matchup Header
            _MatchupHeader(game: game),
            // Box Score (live / finished games only)
            if (game.hasBoxScore) ...[
              const SizedBox(height: 16),
              _BoxScoreCard(game: game),
            ],
            const SizedBox(height: 24),
            // Signal AI Chat Widget (replaces static narrative)
            AIChatWidget(game: game),
            const SizedBox(height: 16),
            // Prediction Card
            _PredictionCard(game: game),
            const SizedBox(height: 16),
            // Elo Ratings Card
            _EloCard(game: game),
            const SizedBox(height: 16),
            // Injury Impact Card (Pro-gated)
            _InjuryCard(game: game),
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
          'Today @ ${game.time}',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _TeamBadge(team: game.homeTeam),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: context.bgCard,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'VS',
                  style: GoogleFonts.spaceMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: context.textMuted,
                  ),
                ),
              ),
            ),
            _TeamBadge(team: game.awayTeam),
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
            color: context.bgCard,
            borderRadius: BorderRadius.circular(16),
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
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.textPrimary,
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
        return AppColors.accentGreen;
      case 'moderate favorite':
        return AppColors.accentGreen;
      case 'lean favorite':
        return AppColors.accentYellow;
      case 'toss-up':
        return AppColors.accentPurple;
      case 'lean underdog':
        return AppColors.accentYellow;
      case 'moderate underdog':
        return AppColors.liveRed;
      case 'strong underdog':
        return AppColors.liveRed;
      default:
        return AppColors.accentPurple;
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Text(
            'MODEL PREDICTION',
            style: GoogleFonts.spaceMono(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: context.textMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          // Confidence tier badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: tierColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tierColor.withOpacity(0.3)),
            ),
            child: Text(
              tier,
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: tierColor,
              ),
            ),
          ),
          // Confidence Score Indicator
          if (game.confidenceScore != null) ...[
            const SizedBox(height: 20),
            _ConfidenceScoreIndicator(
              score: game.confidenceScore!,
              qualifier: game.confidenceQualifier,
              factors: game.confidenceFactors,
            ),
          ],
          const SizedBox(height: 24),
          // Pie Chart with Abbreviations
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
                      game.isHomeFavored
                          ? AppColors.accentGreen
                          : context.borderColor,
                      !game.isHomeFavored
                          ? AppColors.accentGreen
                          : context.borderColor,
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
                        style: GoogleFonts.spaceMono(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentGreen,
                        ),
                      ),
                      Text(
                        '${getEspnAbbreviation(favoredTeam).toUpperCase()} Win',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: context.textSecondary,
                          fontWeight: FontWeight.w700,
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
              color: context.bgSecondary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _DetailRow(
                  label: 'Favored Team',
                  value: favoredTeam,
                  valueColor: AppColors.accentGreen,
                ),
                Divider(height: 20, color: context.borderColor),
                _DetailRow(
                  label: 'Win Probability',
                  value: '${favoredProb.toStringAsFixed(1)}%',
                ),
                Divider(height: 20, color: context.borderColor),
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
    );
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
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: context.textSecondary,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: GoogleFonts.spaceMono(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: valueColor ?? context.textPrimary,
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ELO RATINGS',
            style: GoogleFonts.spaceMono(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: context.textMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _EloTeam(
                team: game.homeTeam,
                elo: homeElo,
                isHigher: homeHigher,
              ),
              Text(
                'vs',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: context.textMuted,
                ),
              ),
              _EloTeam(
                team: game.awayTeam,
                elo: awayElo,
                isHigher: !homeHigher,
              ),
            ],
          ),
        ],
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
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          elo.toInt().toString(),
          style: GoogleFonts.spaceMono(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: isHigher ? AppColors.accentGreen : context.textSecondary,
          ),
        ),
      ],
    );
  }

  String _getAbbreviation(String teamName) {
    return getEspnAbbreviation(teamName).toUpperCase();
  }
}

/// Additional game context card
class _ContextCard extends StatelessWidget {
  final Game game;

  const _ContextCard({required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GAME CONTEXT',
            style: GoogleFonts.spaceMono(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: context.textMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.bgSecondary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _DetailRow(
                  label: 'Game Time',
                  value: game.time,
                ),
                Divider(height: 20, color: context.borderColor),
                _DetailRow(
                  label: 'Home Team',
                  value: game.homeTeam,
                ),
                Divider(height: 20, color: context.borderColor),
                _DetailRow(
                  label: 'Away Team',
                  value: game.awayTeam,
                ),
                Divider(height: 20, color: context.borderColor),
                _DetailRow(
                  label: 'Status',
                  value: game.status,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Injury impact card — always shows the advantage badge; per-player list is
/// gated behind the Pro tier using [ProLockedOverlay].
class _InjuryCard extends ConsumerWidget {
  final Game game;

  const _InjuryCard({required this.game});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = ref.watch(isProProvider);
    final homeInjuries = game.homeInjuries ?? [];
    final awayInjuries = game.awayInjuries ?? [];
    final hasAnyInjuries = homeInjuries.isNotEmpty || awayInjuries.isNotEmpty;

    Color _advantageColor(String? advantage) {
      switch (advantage) {
        case 'home':
          return AppColors.accentGreen;
        case 'away':
          return AppColors.liveRed;
        default:
          return AppColors.accentYellow;
      }
    }

    String _advantageLabel(String? advantage) {
      switch (advantage) {
        case 'home':
          return 'Home Advantage';
        case 'away':
          return 'Away Advantage';
        default:
          return 'Even';
      }
    }

    // Build the locked player list (shown faded + overlay for free users).
    Widget playerList = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (homeInjuries.isNotEmpty) ...[
          Text(
            game.homeTeam,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          ...homeInjuries.map((p) => _InjuryPlayerRow(player: p)),
          const SizedBox(height: 12),
        ],
        if (awayInjuries.isNotEmpty) ...[
          Text(
            game.awayTeam,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          ...awayInjuries.map((p) => _InjuryPlayerRow(player: p)),
        ],
        if (!hasAnyInjuries)
          Text(
            'No significant injuries reported.',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: context.textMuted,
            ),
          ),
      ],
    );

    final advantageColor = _advantageColor(game.injuryAdvantage);
    final advantageLabel = _advantageLabel(game.injuryAdvantage);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with Pro badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'INJURY REPORT',
                style: GoogleFonts.spaceMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: context.textMuted,
                  letterSpacing: 1.5,
                ),
              ),
              if (!isPro)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accentPurple.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.accentPurple.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline,
                          size: 11, color: AppColors.accentPurple),
                      const SizedBox(width: 4),
                      Text(
                        'Pro',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentPurple,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Advantage badge — always visible
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: advantageColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: advantageColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.medical_services_outlined,
                    size: 14, color: advantageColor),
                const SizedBox(width: 6),
                Text(
                  'Health Advantage: $advantageLabel',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: advantageColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Per-player list — gated behind Pro
          ProLockedOverlay(
            isLocked: !isPro,
            featureName: 'Injury Impact Analysis',
            child: playerList,
          ),
        ],
      ),
    );
  }
}

class _InjuryPlayerRow extends StatelessWidget {
  final String player;

  const _InjuryPlayerRow({required this.player});

  @override
  Widget build(BuildContext context) {
    final upper = player.toUpperCase();
    Color statusColor;
    if (upper.contains('(O)') || upper.contains('OUT')) {
      statusColor = AppColors.liveRed;
    } else if (upper.contains('(D)') || upper.contains('DOUBTFUL')) {
      statusColor = AppColors.accentOrange;
    } else if (upper.contains('(Q)') || upper.contains('QUESTIONABLE')) {
      statusColor = AppColors.accentYellow;
    } else {
      statusColor = context.textSecondary;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              player,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: context.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Confidence score indicator with expandable factor breakdown.
///
/// The score bar + qualifier are always visible. The expandable factor
/// breakdown is gated behind the Pro tier.
class _ConfidenceScoreIndicator extends ConsumerStatefulWidget {
  final int score;
  final String? qualifier;
  final Map<String, dynamic>? factors;

  const _ConfidenceScoreIndicator({
    required this.score,
    this.qualifier,
    this.factors,
  });

  @override
  ConsumerState<_ConfidenceScoreIndicator> createState() =>
      _ConfidenceScoreIndicatorState();
}

class _ConfidenceScoreIndicatorState
    extends ConsumerState<_ConfidenceScoreIndicator> {
  bool _isExpanded = false;

  Color _getScoreColor() {
    if (widget.score >= 75) return AppColors.accentGreen;
    if (widget.score >= 50) return AppColors.accentYellow;
    return AppColors.liveRed;
  }

  @override
  Widget build(BuildContext context) {
    final scoreColor = _getScoreColor();
    final isPro = ref.watch(isProProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with qualifier
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Confidence Score',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.textSecondary,
              ),
            ),
            if (widget.qualifier != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scoreColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.qualifier!,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: scoreColor,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // Progress bar
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: widget.score / 100,
                  minHeight: 10,
                  backgroundColor: context.bgSecondary,
                  valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${widget.score}/100',
              style: GoogleFonts.spaceMono(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: scoreColor,
              ),
            ),
          ],
        ),
        // Expandable factors breakdown — Pro-only
        if (widget.factors != null) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              if (!isPro) {
                ProUpgradeScreen.show(context);
                return;
              }
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isPro) ...[
                  Icon(Icons.lock_outline,
                      size: 14, color: AppColors.accentPurple),
                  const SizedBox(width: 4),
                ],
                Text(
                  isPro
                      ? (_isExpanded ? 'Hide Details' : 'Show Details')
                      : 'Pro: Show Details',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.accentBlue,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  isPro
                      ? (_isExpanded ? Icons.expand_less : Icons.expand_more)
                      : Icons.expand_more,
                  size: 16,
                  color: AppColors.accentBlue,
                ),
              ],
            ),
          ),
          if (_isExpanded && isPro) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.bgSecondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _FactorRow(
                    label: 'Consensus Agreement',
                    value: widget.factors!['consensus_agreement'],
                    maxValue: 25,
                  ),
                  const SizedBox(height: 8),
                  _FactorRow(
                    label: 'Feature Alignment',
                    value: widget.factors!['feature_alignment'],
                    maxValue: 25,
                  ),
                  const SizedBox(height: 8),
                  _FactorRow(
                    label: 'Form Stability',
                    value: widget.factors!['form_stability'],
                    maxValue: 20,
                  ),
                  const SizedBox(height: 8),
                  _FactorRow(
                    label: 'Schedule Context',
                    value: widget.factors!['schedule_context'],
                    maxValue: 15,
                  ),
                  const SizedBox(height: 8),
                  _FactorRow(
                    label: 'Matchup History',
                    value: widget.factors!['matchup_history'],
                    maxValue: 15,
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}

/// Individual factor row in breakdown
class _FactorRow extends StatelessWidget {
  final String label;
  final dynamic value;
  final int maxValue;

  const _FactorRow({
    required this.label,
    required this.value,
    required this.maxValue,
  });

  @override
  Widget build(BuildContext context) {
    final numValue = (value is num) ? value.toDouble() : 0.0;
    final percentage = numValue / maxValue;
    
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: context.textSecondary,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage,
                    minHeight: 6,
                    backgroundColor: context.borderColor,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.accentBlue.withOpacity(0.7),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 32,
                child: Text(
                  numValue.toStringAsFixed(1),
                  textAlign: TextAlign.right,
                  style: GoogleFonts.spaceMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Box Score Card
// ---------------------------------------------------------------------------

class _BoxScoreCard extends StatelessWidget {
  final Game game;
  const _BoxScoreCard({required this.game});

  @override
  Widget build(BuildContext context) {
    final labels = game.quarterLabels;
    final homeQ = game.homeQuarters ?? [];
    final awayQ = game.awayQuarters ?? [];
    final homeTotal = int.tryParse(game.homeScore) ?? 0;
    final awayTotal = int.tryParse(game.awayScore) ?? 0;
    final homeWon = homeTotal > awayTotal;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BOX SCORE',
            style: GoogleFonts.spaceMono(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: context.textMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Table(
            columnWidths: {
              0: const FlexColumnWidth(2.2),
              for (int i = 0; i < labels.length; i++)
                i + 1: const FlexColumnWidth(1),
              labels.length + 1: const FlexColumnWidth(1.2),
            },
            children: [
              TableRow(children: [
                _cell(context, '', isHeader: true),
                ...labels.map((l) => _cell(context, l, isHeader: true)),
                _cell(context, 'T', isHeader: true),
              ]),
              TableRow(children: [
                _teamCell(context, game.homeTeam, bold: homeWon),
                ...List.generate(labels.length, (i) {
                  final val = i < homeQ.length ? homeQ[i].toString() : '-';
                  return _cell(context, val, bold: homeWon);
                }),
                _cell(context, homeTotal.toString(), bold: homeWon, accent: homeWon),
              ]),
              TableRow(children: [
                _teamCell(context, game.awayTeam, bold: !homeWon),
                ...List.generate(labels.length, (i) {
                  final val = i < awayQ.length ? awayQ[i].toString() : '-';
                  return _cell(context, val, bold: !homeWon);
                }),
                _cell(context, awayTotal.toString(), bold: !homeWon, accent: !homeWon),
              ]),
            ],
          ),
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
            ...game.leaders!.map((l) => _leaderRow(context, l)),
          ],
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, String text,
      {bool isHeader = false, bool bold = false, bool accent = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
                  : context.textPrimary,
        ),
      ),
    );
  }

  Widget _teamCell(BuildContext context, String teamName, {bool bold = false}) {
    final abbr = getEspnAbbreviation(teamName).toUpperCase();
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

  Widget _leaderRow(BuildContext context, GameLeader leader) {
    IconData icon;
    String label;
    switch (leader.category) {
      case 'points':
        icon = Icons.sports_basketball;
        label = 'PTS';
        break;
      case 'rebounds':
        icon = Icons.swap_vert;
        label = 'REB';
        break;
      case 'assists':
        icon = Icons.handshake_outlined;
        label = 'AST';
        break;
      default:
        icon = Icons.star_outline;
        label = leader.category.toUpperCase();
    }
    final teamName = leader.isHome ? game.homeTeam : game.awayTeam;
    final abbr = getEspnAbbreviation(teamName).toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: context.bgSecondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: context.textMuted),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 36,
            child: Text(
              label,
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
