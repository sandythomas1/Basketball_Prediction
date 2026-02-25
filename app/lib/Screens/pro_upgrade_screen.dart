import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Full-screen paywall that appears when the user exhausts free AI chats.
///
/// Subscription logic is a placeholder -- wire RevenueCat / StoreKit here.
class ProUpgradeScreen extends StatelessWidget {
  const ProUpgradeScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => const ProUpgradeScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _buildHero(context),
                    const SizedBox(height: 28),
                    _buildFeatures(context),
                    const SizedBox(height: 28),
                    _buildPricingCard(context),
                    const SizedBox(height: 24),
                    _buildCta(context),
                    const SizedBox(height: 8),
                    _buildRestoreLink(context),
                    const SizedBox(height: 16),
                    _buildFreeReminder(context),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.textPrimary.withOpacity(0.06),
                border: Border.all(
                  color: context.textPrimary.withOpacity(0.08),
                ),
              ),
              child: Icon(Icons.close, size: 18, color: context.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero ────────────────────────────────────────────────────────────────────

  Widget _buildHero(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.accentPurple.withOpacity(0.15),
                AppColors.accentBlue.withOpacity(0.15),
              ],
            ),
            border: Border.all(
              color: AppColors.accentPurple.withOpacity(0.25),
            ),
          ),
          child: const Center(
            child: Icon(Icons.auto_awesome, size: 32, color: AppColors.accentPurple),
          ),
        ),
        const SizedBox(height: 20),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppColors.accentPurple, AppColors.accentBlue],
          ).createShader(bounds),
          child: Text(
            'Upgrade to Pro',
            style: GoogleFonts.dmSans(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Unlock unlimited AI game analysis\nand get the edge on every matchup.',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 15,
            color: context.textMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: AppColors.liveRed.withOpacity(0.1),
            border: Border.all(color: AppColors.liveRed.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 13, color: AppColors.liveRed),
              const SizedBox(width: 6),
              Text(
                '3 / 3 free chats used today',
                style: GoogleFonts.spaceMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.liveRed,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Features ───────────────────────────────────────────────────────────────

  Widget _buildFeatures(BuildContext context) {
    const features = [
      _FeatureData(
        icon: Icons.chat_bubble_outline,
        color: AppColors.accentPurple,
        title: 'Unlimited AI Chats',
        subtitle: 'No daily cap — ask as many questions as you want',
      ),
      _FeatureData(
        icon: Icons.bolt,
        color: AppColors.accentBlue,
        title: 'Priority Responses',
        subtitle: 'Faster model with deeper, more detailed analysis',
      ),
      _FeatureData(
        icon: Icons.insights,
        color: AppColors.accentGreen,
        title: 'Advanced Insights',
        subtitle: 'Player props, injury impact scores, and trend data',
      ),
      _FeatureData(
        icon: Icons.notifications_active_outlined,
        color: AppColors.accentOrange,
        title: 'Smart Alerts',
        subtitle: 'Get notified when high-confidence picks drop',
      ),
    ];

    return Column(
      children: features
          .map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildFeatureRow(context, f),
              ))
          .toList(),
    );
  }

  Widget _buildFeatureRow(BuildContext context, _FeatureData data) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: data.color.withOpacity(0.12),
            ),
            child: Icon(data.icon, size: 20, color: data.color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.subtitle,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: context.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Pricing card ───────────────────────────────────────────────────────────

  Widget _buildPricingCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accentPurple.withOpacity(0.06),
            AppColors.accentBlue.withOpacity(0.06),
          ],
        ),
        border: Border.all(color: AppColors.accentPurple.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            'SIGNAL PRO',
            style: GoogleFonts.spaceMono(
              fontSize: 11,
              letterSpacing: 1.5,
              color: context.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '\$',
                  style: GoogleFonts.dmSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentPurple,
                  ),
                ),
              ),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppColors.accentPurple, AppColors.accentBlue],
                ).createShader(bounds),
                child: Text(
                  '4',
                  style: GoogleFonts.dmSans(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(
                  '.99/mo',
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    color: context.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Cancel anytime  \u2022  3-day free trial',
            style: GoogleFonts.dmSans(fontSize: 13, color: context.textMuted),
          ),
        ],
      ),
    );
  }

  // ── CTA button ─────────────────────────────────────────────────────────────

  Widget _buildCta(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.accentPurple, AppColors.accentBlue],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentPurple.withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: TextButton(
          onPressed: () {
            // TODO: integrate RevenueCat / StoreKit purchase flow
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Subscriptions coming soon!'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            'Start Free Trial',
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  // ── Restore + free reminder ────────────────────────────────────────────────

  Widget _buildRestoreLink(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // TODO: restore purchases via RevenueCat
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Restore purchases coming soon!'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Restore purchase',
          style: GoogleFonts.dmSans(fontSize: 13, color: context.textMuted),
        ),
      ),
    );
  }

  Widget _buildFreeReminder(BuildContext context) {
    return Text(
      'Not ready? You\u2019ll still get 3 free AI chats\nevery day \u2014 resets at midnight.',
      textAlign: TextAlign.center,
      style: GoogleFonts.dmSans(
        fontSize: 13,
        color: context.textMuted,
        height: 1.5,
      ),
    );
  }
}

class _FeatureData {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _FeatureData({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
}
