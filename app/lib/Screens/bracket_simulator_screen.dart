import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../Providers/api_service.dart';
import '../theme/app_theme.dart';

class BracketSimulatorScreen extends ConsumerStatefulWidget {
  const BracketSimulatorScreen({super.key});

  @override
  ConsumerState<BracketSimulatorScreen> createState() => _BracketSimulatorScreenState();
}

class _BracketSimulatorScreenState extends ConsumerState<BracketSimulatorScreen> {
  bool _isLoading = false;
  List<MapEntry<String, dynamic>> _results = [];

  final List<int> _mock64Teams = [
    2000, 2005, 2006, 2010, 333, 2011, 2016, 44, 2026, 9, 12, 8, 2032, 2029,
    349, 2, 2046, 252, 2050, 239, 91, 2057, 2065, 2066, 68, 103, 104, 189, 71,
    225, 2803, 2083, 2084, 2086, 13, 2934, 2239, 2463, 2856, 25, 2097, 2099,
    2110, 2115, 2117, 232, 2127, 2429, 236, 2130, 2132, 228, 325, 324, 2142,
    38, 36, 171, 2154, 172, 156, 159, 2166, 2168,
  ];

  Future<void> _simulate() async {
    setState(() {
      _isLoading = true;
      _results = [];
    });

    final api = ref.read(apiServiceProvider);
    final response = await api.simulateBracket(_mock64Teams, iterations: 1000);

    if (response != null && response['results'] != null) {
      final Map<String, dynamic> rawResults = response['results'];
      final sortedEntries = rawResults.entries.toList()
        ..sort((a, b) => (b.value['W'] as num).compareTo(a.value['W'] as num));
      setState(() => _results = sortedEntries);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Simulation failed. Please try again.')),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'March Madness Simulator',
              style: GoogleFonts.dmSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              'Monte Carlo CBB · 10,000 iterations',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Simulate button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF3B82F6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isLoading ? null : _simulate,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.sports_basketball, size: 22, color: Colors.white),
                            const SizedBox(width: 10),
                            Text(
                              'Simulate 10,000 Iterations',
                              style: GoogleFonts.dmSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),

          // Empty hint
          if (_results.isEmpty && !_isLoading)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Tap to simulate the 64-team bracket using our Monte Carlo CBB AI model.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: context.textMuted,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ),

          // Results
          if (_results.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Row(
                children: [
                  Expanded(child: Divider(color: context.borderColor)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'CHAMPIONSHIP WIN PROBABILITY',
                      style: GoogleFonts.spaceMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: context.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: context.borderColor)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final entry = _results[index];
                  final probs = entry.value;
                  final winPct = ((probs['W'] as num) * 100).toStringAsFixed(1);
                  final f4Pct = ((probs['F4'] as num) * 100).toStringAsFixed(1);
                  return _ResultCard(
                    rank: index + 1,
                    teamId: entry.key,
                    winPct: winPct,
                    f4Pct: f4Pct,
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final int rank;
  final String teamId;
  final String winPct;
  final String f4Pct;

  const _ResultCard({
    required this.rank,
    required this.teamId,
    required this.winPct,
    required this.f4Pct,
  });

  @override
  Widget build(BuildContext context) {
    final (badgeBg, badgeBorder, badgeText) = switch (rank) {
      1 => (
          const Color(0xFFD29922).withValues(alpha: 0.15),
          const Color(0xFFD29922).withValues(alpha: 0.4),
          const Color(0xFFD29922),
        ),
      2 => (
          const Color(0xFF8B949E).withValues(alpha: 0.12),
          const Color(0xFF8B949E).withValues(alpha: 0.3),
          const Color(0xFF8B949E),
        ),
      3 => (
          const Color(0xFFE07B2A).withValues(alpha: 0.12),
          const Color(0xFFE07B2A).withValues(alpha: 0.3),
          const Color(0xFFE07B2A),
        ),
      _ => (
          context.bgSecondary,
          context.borderColor,
          context.textMuted,
        ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: badgeBorder, width: 1.5),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: badgeText,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Team info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Team $teamId',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                Text(
                  'Final Four: $f4Pct%',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Win %
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$winPct%',
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentGreen,
                ),
              ),
              Text(
                'Win %',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: context.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
