import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../Providers/subscription_provider.dart';
import '../Services/subscription_service.dart';
import '../theme/app_theme.dart';

/// Full-screen paywall shown when the user hits a Pro-only feature.
///
/// Lets the user choose between Monthly ($4.99) and Annual ($29.99) plans,
/// then drives the purchase through [SubscriptionService].
class ProUpgradeScreen extends ConsumerStatefulWidget {
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
  ConsumerState<ProUpgradeScreen> createState() => _ProUpgradeScreenState();
}

class _ProUpgradeScreenState extends ConsumerState<ProUpgradeScreen> {
  // 'monthly' or 'annual'
  String _selectedPlan = 'annual';
  bool _isLoading = false;
  String? _errorMessage;

  // Packages fetched from RevenueCat
  Package? _monthlyPackage;
  Package? _annualPackage;
  bool _offeringsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    final service = ref.read(subscriptionServiceProvider);
    final packages = await service.getProPackages();
    if (mounted) {
      setState(() {
        _monthlyPackage = packages['monthly'];
        _annualPackage = packages['annual'];
        _offeringsLoading = false;
      });
    }
  }

  Future<void> _purchase() async {
    final package =
        _selectedPlan == 'annual' ? _annualPackage : _monthlyPackage;

    if (package == null) {
      setState(() {
        _errorMessage =
            'Products not available yet — make sure your Play Console subscription products are live.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final service = ref.read(subscriptionServiceProvider);
    final result = await service.purchasePackage(package);

    if (!mounted) return;

    if (result.success && result.isPro) {
      // Invalidate the RevenueCat provider so isProProvider refreshes.
      ref.invalidate(revenueCatProProvider);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Welcome to Signal Pro! All features are now unlocked.',
            style: GoogleFonts.dmSans(fontSize: 14),
          ),
          backgroundColor: AppColors.accentGreen,
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (result.error != null &&
        !result.error!.contains('cancelled')) {
      setState(() {
        _errorMessage = result.error;
      });
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _restore() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final service = ref.read(subscriptionServiceProvider);
    final result = await service.restorePurchases();

    if (!mounted) return;

    if (result.isPro) {
      ref.invalidate(revenueCatProProvider);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pro subscription restored!',
            style: GoogleFonts.dmSans(fontSize: 14),
          ),
          backgroundColor: AppColors.accentGreen,
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (result.success && !result.isPro) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No active subscription found.',
            style: GoogleFonts.dmSans(fontSize: 14),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (result.error != null) {
      setState(() => _errorMessage = result.error);
    }

    if (mounted) setState(() => _isLoading = false);
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
                    _buildPlanToggle(context),
                    const SizedBox(height: 16),
                    _buildPricingCard(context),
                    const SizedBox(height: 24),
                    _buildCta(context),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      _buildError(context),
                    ],
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
            onTap: _isLoading ? null : () => Navigator.of(context).pop(),
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
            child: Icon(Icons.auto_awesome,
                size: 32, color: AppColors.accentPurple),
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
        icon: Icons.insights,
        color: AppColors.accentBlue,
        title: 'Confidence Breakdown',
        subtitle:
            'See exactly why the model is confident — factor-by-factor',
      ),
      _FeatureData(
        icon: Icons.medical_services_outlined,
        color: AppColors.accentGreen,
        title: 'Injury Impact Analysis',
        subtitle: 'Full per-player injury reports & health advantage scores',
      ),
      _FeatureData(
        icon: Icons.bolt,
        color: AppColors.accentOrange,
        title: 'Quick AI Narratives',
        subtitle: 'One-tap AI game previews for every matchup',
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

  // ── Plan toggle ────────────────────────────────────────────────────────────

  Widget _buildPlanToggle(BuildContext context) {
    final monthlyLabel = _monthlyPackage != null
        ? '${_monthlyPackage!.storeProduct.priceString}/mo'
        : '\$4.99/mo';
    final annualLabel = _annualPackage != null
        ? '${_annualPackage!.storeProduct.priceString}/yr'
        : '\$29.99/yr';

    return Container(
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          _PlanChip(
            label: 'Monthly',
            sublabel: monthlyLabel,
            selected: _selectedPlan == 'monthly',
            onTap: () => setState(() => _selectedPlan = 'monthly'),
          ),
          _PlanChip(
            label: 'Annual',
            sublabel: annualLabel,
            badge: 'Save 50%',
            selected: _selectedPlan == 'annual',
            onTap: () => setState(() => _selectedPlan = 'annual'),
          ),
        ],
      ),
    );
  }

  // ── Pricing card ───────────────────────────────────────────────────────────

  Widget _buildPricingCard(BuildContext context) {
    final isAnnual = _selectedPlan == 'annual';
    final pkg = isAnnual ? _annualPackage : _monthlyPackage;
    final price = pkg != null ? pkg.storeProduct.priceString : (isAnnual ? '\$29.99' : '\$4.99');
    final period = isAnnual ? '/yr' : '/mo';
    final subline = isAnnual
        ? 'Just \$2.50/month  •  Cancel anytime'
        : 'Cancel anytime  •  3-day free trial';

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
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppColors.accentPurple, AppColors.accentBlue],
                ).createShader(bounds),
                child: Text(
                  price,
                  style: GoogleFonts.dmSans(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  period,
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
            subline,
            style: GoogleFonts.dmSans(fontSize: 13, color: context.textMuted),
          ),
        ],
      ),
    );
  }

  // ── CTA button ─────────────────────────────────────────────────────────────

  Widget _buildCta(BuildContext context) {
    final isAnnual = _selectedPlan == 'annual';
    final ctaLabel =
        isAnnual ? 'Get Annual Plan' : 'Start Free Trial';

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
          onPressed: (_isLoading || _offeringsLoading) ? null : _purchase,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : _offeringsLoading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Loading plans…',
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      ctaLabel,
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

  // ── Error message ──────────────────────────────────────────────────────────

  Widget _buildError(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.liveRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.liveRed.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: AppColors.liveRed),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppColors.liveRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Restore + free reminder ────────────────────────────────────────────────

  Widget _buildRestoreLink(BuildContext context) {
    return GestureDetector(
      onTap: _isLoading ? null : _restore,
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

// ── Plan toggle chip ──────────────────────────────────────────────────────────

class _PlanChip extends StatelessWidget {
  final String label;
  final String sublabel;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  const _PlanChip({
    required this.label,
    required this.sublabel,
    this.badge,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accentPurple.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(color: AppColors.accentPurple.withOpacity(0.5))
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? AppColors.accentPurple
                      : context.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sublabel,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: selected ? AppColors.accentPurple : context.textMuted,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge!,
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentGreen,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Feature row data ──────────────────────────────────────────────────────────

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
