import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../Models/playoff_models.dart';
import '../Providers/playoff_provider.dart';
import '../theme/app_theme.dart';

/// Playoff bracket screen showing all series by conference.
class PlayoffBracketScreen extends ConsumerWidget {
  const PlayoffBracketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bracketAsync = ref.watch(playoffBracketProvider);

    return Scaffold(
      backgroundColor: context.bgPrimary,
      appBar: AppBar(
        backgroundColor: context.bgSecondary,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppColors.accentOrange, AppColors.accentYellow],
          ).createShader(bounds),
          child: Text(
            'Playoff Bracket',
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
              icon: bracketAsync.isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.textSecondary,
                      ),
                    )
                  : Icon(Icons.refresh, color: context.textSecondary),
              onPressed: bracketAsync.isLoading
                  ? null
                  : () => ref.read(playoffBracketProvider.notifier).refresh(),
            ),
          ),
        ],
      ),
      body: bracketAsync.when(
        data: (bracket) {
          if (bracket == null) return _buildInactive(context);
          return _BracketBody(bracket: bracket);
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: AppColors.accentOrange),
        ),
        error: (e, _) => Center(
          child: Text(
            'Failed to load bracket',
            style: GoogleFonts.dmSans(color: context.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildInactive(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events_outlined, size: 56, color: context.textSecondary),
          const SizedBox(height: 16),
          Text(
            'Playoffs Not Active',
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back during the NBA Playoffs',
            style: GoogleFonts.dmSans(fontSize: 14, color: context.textSecondary),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Bracket body with East / West tabs
// =============================================================================

class _BracketBody extends StatelessWidget {
  final PlayoffBracket bracket;

  const _BracketBody({required this.bracket});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: context.bgSecondary,
            child: TabBar(
              indicatorColor: AppColors.accentOrange,
              labelColor: AppColors.accentOrange,
              unselectedLabelColor: context.textSecondary,
              labelStyle: GoogleFonts.dmSans(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              tabs: const [
                Tab(text: 'East'),
                Tab(text: 'West'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _SeriesList(series: bracket.east, finals: bracket.finals),
                _SeriesList(series: bracket.west, finals: bracket.finals),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Series list (one tab's worth of series + optional Finals card)
// =============================================================================

class _SeriesList extends StatelessWidget {
  final List<PlayoffSeriesInfo> series;
  final PlayoffSeriesInfo? finals;

  const _SeriesList({required this.series, this.finals});

  @override
  Widget build(BuildContext context) {
    final items = [...series];
    final showFinals = finals != null;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length + (showFinals ? 1 : 0),
      itemBuilder: (context, i) {
        if (showFinals && i == items.length) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 4),
                child: Text(
                  'NBA Finals',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              _SeriesCard(series: finals!),
            ],
          );
        }
        return _SeriesCard(series: items[i]);
      },
    );
  }
}

// =============================================================================
// Series card
// =============================================================================

class _SeriesCard extends StatelessWidget {
  final PlayoffSeriesInfo series;

  const _SeriesCard({required this.series});

  @override
  Widget build(BuildContext context) {
    final isActive = series.isInProgress;
    final isComplete = series.isComplete;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        '/playoff/series',
        arguments: series.seriesId,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? AppColors.accentOrange.withValues(alpha: 0.4)
                : context.borderColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Round label + status pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatRound(series.roundName),
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: context.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isActive)
                  _StatusPill(
                    label: 'Active',
                    color: AppColors.accentOrange,
                  )
                else if (isComplete)
                  _StatusPill(
                    label: 'Final',
                    color: context.textSecondary,
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Teams + series score
            Row(
              children: [
                Expanded(
                  child: _TeamEntry(
                    name: series.higherSeedName,
                    wins: series.higherSeedWins,
                    isLeading: series.higherSeedWins > series.lowerSeedWins,
                    isWinner: isComplete && series.winnerId == series.higherSeedId,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'vs',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: context.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: _TeamEntry(
                    name: series.lowerSeedName,
                    wins: series.lowerSeedWins,
                    isLeading: series.lowerSeedWins > series.higherSeedWins,
                    isWinner: isComplete && series.winnerId == series.lowerSeedId,
                    alignRight: true,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Context string
            Text(
              series.seriesContext,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: context.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
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

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _TeamEntry extends StatelessWidget {
  final String name;
  final int wins;
  final bool isLeading;
  final bool isWinner;
  final bool alignRight;

  const _TeamEntry({
    required this.name,
    required this.wins,
    this.isLeading = false,
    this.isWinner = false,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    final shortName = name.split(' ').last;
    final winsColor = isLeading || isWinner
        ? AppColors.accentOrange
        : context.textSecondary;
    final nameColor = isWinner ? AppColors.accentOrange : context.textPrimary;
    final nameFontWeight = isLeading || isWinner ? FontWeight.w700 : FontWeight.w500;

    final nameWidget = Text(
      shortName,
      style: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: nameFontWeight,
        color: nameColor,
      ),
    );
    final winsWidget = Text(
      '$wins',
      style: GoogleFonts.dmSans(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: winsColor,
      ),
    );

    return Row(
      mainAxisAlignment: alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: alignRight
          ? [winsWidget, const SizedBox(width: 8), nameWidget]
          : [nameWidget, const SizedBox(width: 8), winsWidget],
    );
  }
}
