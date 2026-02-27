import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// A semi-transparent overlay placed on top of a widget that is locked behind
/// the Pro paywall. Tapping it shows a snackbar / navigates to the paywall.
///
/// Usage:
/// ```dart
/// ProLockedOverlay(
///   isLocked: userProfile.isFree,
///   featureName: 'Confidence Score Breakdown',
///   child: _ConfidenceScoreFactors(...),
/// )
/// ```
class ProLockedOverlay extends StatelessWidget {
  /// Whether the overlay should be shown (i.e. user is on the free tier).
  final bool isLocked;

  /// A human-readable name shown in the upgrade prompt.
  final String featureName;

  /// The child widget that will be blurred / covered when locked.
  final Widget child;

  const ProLockedOverlay({
    super.key,
    required this.isLocked,
    required this.featureName,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLocked) return child;

    return Stack(
      children: [
        // Blurred / faded content underneath
        IgnorePointer(
          child: Opacity(
            opacity: 0.25,
            child: child,
          ),
        ),

        // Lock overlay
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              // TODO: Navigate to PaywallScreen when it exists
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Upgrade to Pro to unlock $featureName',
                    style: GoogleFonts.dmSans(fontSize: 14),
                  ),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 3),
                  action: SnackBarAction(
                    label: 'Upgrade',
                    textColor: AppColors.accentPurple,
                    onPressed: () {
                      // TODO: navigate to paywall
                    },
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accentPurple.withOpacity(0.12),
                        AppColors.accentBlue.withOpacity(0.12),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.accentPurple.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 18,
                        color: AppColors.accentPurple,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Pro Feature',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentPurple,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
