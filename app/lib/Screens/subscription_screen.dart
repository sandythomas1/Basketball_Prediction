import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Providers/subscription_provider.dart';
import '../theme/app_theme.dart';

/// Full subscription management page accessible from the drawer.
///
/// - **Free users** see the feature list, plan toggle, pricing, and purchase CTA.
/// - **Pro users** see their active plan details and a link to manage on Play Store.
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  // Plan selection for Free users
  String _selectedPlan = 'annual';
  bool _isLoading = false;
  String? _errorMessage;

  // RevenueCat data
  Package? _monthlyPackage;
  Package? _annualPackage;
  bool _offeringsLoading = true;

  // Pro user info
  CustomerInfo? _customerInfo;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  bool get _hasPackages => _monthlyPackage != null || _annualPackage != null;

  Future<void> _loadData() async {
    final service = ref.read(subscriptionServiceProvider);
    final packages = await service.getProPackages();
    final info = await service.getCustomerInfo();
    if (mounted) {
      setState(() {
        _monthlyPackage = packages['monthly'];
        _annualPackage = packages['annual'];
        _customerInfo = info;
        _offeringsLoading = false;
        // Proactively show error when offerings fail to load
        if (!_hasPackages) {
          _errorMessage =
              'Subscription products are not available yet. '
              'Please check back later or contact support.';
        }
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
      ref.invalidate(revenueCatProProvider);
      _loadData(); // refresh customer info
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
    } else if (result.error != null && !result.error!.contains('cancelled')) {
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
      _loadData();
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

  Future<void> _openPlayStoreSubscriptions() async {
    // Deep link to Play Store subscription management
    final uri = Uri.parse(
      'https://play.google.com/store/account/subscriptions',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isPro = ref.watch(isProProvider);

    return Scaffold(
      backgroundColor: context.bgPrimary,
      appBar: AppBar(
        backgroundColor: context.bgSecondary,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Subscription',
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: isPro ? _buildProView(context) : _buildFreeView(context),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PRO VIEW
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildProView(BuildContext context) {
    // Try to extract active entitlement info
    final entitlement =
        _customerInfo?.entitlements.active['pro'];
    final expiryStr = entitlement?.expirationDate;
    DateTime? expiry;
    if (expiryStr != null) {
      expiry = DateTime.tryParse(expiryStr);
    }

    return Column(
      children: [
        const SizedBox(height: 12),

        // ── Pro badge ────────────────────────────────────────────────────
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.accentPurple.withOpacity(0.20),
                AppColors.accentBlue.withOpacity(0.20),
              ],
            ),
            border: Border.all(
              color: AppColors.accentPurple.withOpacity(0.35),
            ),
          ),
          child: const Center(
            child: Icon(Icons.workspace_premium,
                size: 40, color: AppColors.accentPurple),
          ),
        ),
        const SizedBox(height: 20),

        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppColors.accentPurple, AppColors.accentBlue],
          ).createShader(bounds),
          child: Text(
            'You\'re on Pro',
            style: GoogleFonts.dmSans(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'All premium features are unlocked.',
          style: GoogleFonts.dmSans(
            fontSize: 15,
            color: context.textMuted,
          ),
        ),
        const SizedBox(height: 28),

        // ── Plan details card ────────────────────────────────────────────
        Container(
          width: double.infinity,
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
                'PLAN DETAILS',
                style: GoogleFonts.spaceMono(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: context.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              _detailRow(context, 'Status', 'Active',
                  valueColor: AppColors.accentGreen),
              const SizedBox(height: 12),
              if (entitlement?.productIdentifier != null)
                _detailRow(
                  context,
                  'Plan',
                  entitlement!.productIdentifier.contains('annual')
                      ? 'Annual'
                      : 'Monthly',
                ),
              if (entitlement?.productIdentifier != null)
                const SizedBox(height: 12),
              if (expiry != null)
                _detailRow(
                  context,
                  'Renews',
                  '${_monthName(expiry.month)} ${expiry.day}, ${expiry.year}',
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Unlocked features ────────────────────────────────────────────
        _buildUnlockedFeatures(context),
        const SizedBox(height: 28),

        // ── Manage on Play Store ─────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _openPlayStoreSubscriptions,
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(
              'Manage on Play Store',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accentPurple,
              side: BorderSide(
                  color: AppColors.accentPurple.withOpacity(0.4)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _detailRow(BuildContext context, String label, String value,
      {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            color: context.textMuted,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor ?? context.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildUnlockedFeatures(BuildContext context) {
    const features = [
      ('Unlimited AI Chats', Icons.chat_bubble_outline),
      ('Confidence Breakdown', Icons.insights),
      ('Injury Impact Analysis', Icons.medical_services_outlined),
      ('Quick AI Narratives', Icons.bolt),
    ];

    return Container(
      width: double.infinity,
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
            'UNLOCKED FEATURES',
            style: GoogleFonts.spaceMono(
              fontSize: 11,
              letterSpacing: 1.5,
              color: context.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        size: 18, color: AppColors.accentGreen),
                    const SizedBox(width: 10),
                    Icon(f.$2, size: 18, color: context.textSecondary),
                    const SizedBox(width: 10),
                    Text(
                      f.$1,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: context.textPrimary,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return names[month - 1];
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FREE VIEW
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildFreeView(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 4),
        _buildTierBadge(context),
        const SizedBox(height: 24),
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
    );
  }

  // ── Tier badge ─────────────────────────────────────────────────────────

  Widget _buildTierBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.textMuted.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.textMuted.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_outline, size: 16, color: context.textSecondary),
          const SizedBox(width: 6),
          Text(
            'Current Plan: Free',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero ────────────────────────────────────────────────────────────────

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
      ],
    );
  }

  // ── Features ───────────────────────────────────────────────────────────

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
        subtitle: 'See exactly why the model is confident — factor-by-factor',
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

  // ── Plan toggle ────────────────────────────────────────────────────────

  Widget _buildPlanToggle(BuildContext context) {
    // Use real store prices when available
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

  // ── Pricing card ───────────────────────────────────────────────────────

  Widget _buildPricingCard(BuildContext context) {
    final isAnnual = _selectedPlan == 'annual';

    // Use real store prices when available, otherwise fall back to defaults
    final pkg = isAnnual ? _annualPackage : _monthlyPackage;
    final String price;
    final String cents;
    if (pkg != null) {
      final priceStr = pkg.storeProduct.priceString; // e.g. "$29.99"
      price = priceStr;
      cents = isAnnual ? '/yr' : '/mo';
    } else {
      price = isAnnual ? '\$29' : '\$4';
      cents = isAnnual ? '.99/yr' : '.99/mo';
    }
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
                  cents,
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

  // ── CTA button ─────────────────────────────────────────────────────────

  Widget _buildCta(BuildContext context) {
    final isAnnual = _selectedPlan == 'annual';
    final ctaLabel = isAnnual ? 'Get Annual Plan' : 'Start Free Trial';
    final canPurchase = !_isLoading && !_offeringsLoading && _hasPackages;

    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: canPurchase
                ? const [AppColors.accentPurple, AppColors.accentBlue]
                : [Colors.grey.shade600, Colors.grey.shade500],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: canPurchase
              ? [
                  BoxShadow(
                    color: AppColors.accentPurple.withOpacity(0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: TextButton(
          onPressed: canPurchase ? _purchase : null,
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

  // ── Error message ──────────────────────────────────────────────────────

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

  // ── Restore + free reminder ────────────────────────────────────────────

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
