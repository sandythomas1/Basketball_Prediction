import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../Models/radar_entry.dart';
import '../Providers/radar_provider.dart';
import '../theme/app_theme.dart';

/// Recruit Radar — Men's CBB Transfer Portal Intelligence Feed.
/// Shows AI-processed portal entries streamed in real-time from Firebase RTDB.
class RecruitRadarScreen extends ConsumerWidget {
  const RecruitRadarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(radarEntriesProvider);
    final lastUpdatedAsync = ref.watch(radarLastUpdatedProvider);

    return Scaffold(
      backgroundColor: context.bgPrimary,
      appBar: AppBar(
        backgroundColor: context.bgSecondary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppColors.accentOrange, AppColors.accentBlue],
          ).createShader(bounds),
          child: Text(
            'Recruit Radar',
            style: GoogleFonts.dmSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: _LastUpdatedBanner(lastUpdatedAsync: lastUpdatedAsync),
        ),
      ),
      body: entriesAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return _EmptyState();
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: entries.length,
            itemBuilder: (context, index) => _RadarCard(entry: entries[index]),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accentOrange),
        ),
        error: (error, _) => _ErrorState(
          onRetry: () => ref.invalidate(radarEntriesProvider),
        ),
      ),
    );
  }
}

// ── Last-updated banner ───────────────────────────────────────────────────────

class _LastUpdatedBanner extends StatelessWidget {
  final AsyncValue<String?> lastUpdatedAsync;

  const _LastUpdatedBanner({required this.lastUpdatedAsync});

  @override
  Widget build(BuildContext context) {
    final label = lastUpdatedAsync.when(
      data: (ts) {
        if (ts == null || ts.isEmpty) return 'Awaiting first update';
        final dt = DateTime.tryParse(ts);
        if (dt == null) return 'Updated recently';
        final diff = DateTime.now().toUtc().difference(dt.toUtc());
        if (diff.inSeconds < 60) return 'Updated just now';
        if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes}m ago';
        if (diff.inHours < 24) return 'Updated ${diff.inHours}h ago';
        return 'Updated ${diff.inDays}d ago';
      },
      loading: () => 'Loading...',
      error: (_, _) => '',
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 8, left: 16),
      color: context.bgSecondary,
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.accentGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$label · Men\'s CBB Transfer Portal',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: context.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Radar card ────────────────────────────────────────────────────────────────

class _RadarCard extends StatelessWidget {
  final RadarEntry entry;

  const _RadarCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: player name + timestamp
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.playerName,
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                    if (entry.schoolFrom.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'From ${entry.schoolFrom}',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: context.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _SentimentBadge(label: entry.sentimentLabel, score: entry.sentimentScore),
                  if (entry.relativeTime.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        entry.relativeTime,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: context.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Summary
          Text(
            entry.summary,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: context.textSecondary,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 12),

          // Sentiment meter
          _SentimentMeter(score: entry.sentimentScore),

          // Lead schools chips
          if (entry.leadSchools.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SchoolChips(schools: entry.leadSchools),
          ],

          // Visit dates
          if (entry.visitDates.isNotEmpty) ...[
            const SizedBox(height: 8),
            _VisitDates(dates: entry.visitDates),
          ],
        ],
      ),
    );
  }
}

// ── Sentiment badge ───────────────────────────────────────────────────────────

class _SentimentBadge extends StatelessWidget {
  final String label;
  final double score;

  const _SentimentBadge({required this.label, required this.score});

  Color _badgeColor() {
    if (score >= 8.0) return AppColors.accentGreen;
    if (score >= 6.0) return AppColors.accentOrange;
    if (score >= 4.0) return AppColors.accentBlue;
    return AppColors.liveRed;
  }

  @override
  Widget build(BuildContext context) {
    final color = _badgeColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ── Sentiment meter ───────────────────────────────────────────────────────────

class _SentimentMeter extends StatelessWidget {
  final double score;

  const _SentimentMeter({required this.score});

  Color _meterColor() {
    if (score >= 7.5) return AppColors.accentGreen;
    if (score >= 5.0) return AppColors.accentOrange;
    return AppColors.liveRed;
  }

  @override
  Widget build(BuildContext context) {
    final value = ((score - 1.0) / 9.0).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Buzz Score',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: context.textMuted,
              ),
            ),
            Text(
              score.toStringAsFixed(1),
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _meterColor(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: context.borderColor,
            valueColor: AlwaysStoppedAnimation<Color>(_meterColor()),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

// ── School chips ──────────────────────────────────────────────────────────────

class _SchoolChips extends StatelessWidget {
  final List<String> schools;

  const _SchoolChips({required this.schools});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lead Schools',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            color: context.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: schools
              .map(
                (school) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.accentBlue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    school,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.accentBlue,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

// ── Visit dates ───────────────────────────────────────────────────────────────

class _VisitDates extends StatelessWidget {
  final List<String> dates;

  const _VisitDates({required this.dates});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.calendar_today_outlined,
          size: 13,
          color: context.textMuted,
        ),
        const SizedBox(width: 4),
        Text(
          'Visits: ${dates.join(', ')}',
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: context.textMuted,
          ),
        ),
      ],
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.radar_outlined,
              size: 56,
              color: context.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'No Portal Activity Yet',
              style: GoogleFonts.dmSans(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Recruit Radar checks On3 and X every 30 minutes.\nCheck back soon for the latest transfer portal intelligence.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: context.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: context.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load Recruit Radar',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
