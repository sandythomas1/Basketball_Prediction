import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Services/subscription_service.dart';
import 'user_provider.dart';

// ── SubscriptionService provider ──────────────────────────────────────────────

/// Global access to the singleton [SubscriptionService].
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService.instance;
});

// ── RevenueCat live entitlement check ─────────────────────────────────────────

/// Async provider that fetches the live Pro entitlement state from RevenueCat.
///
/// This is the source of truth on app launch and after purchases / restores.
/// Falls back to `false` on error so the app degrades gracefully.
final revenueCatProProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(subscriptionServiceProvider);
  return service.isProActive();
});

// ── Unified Pro status ────────────────────────────────────────────────────────

/// Whether the current user is on the Pro tier.
///
/// Priority:
/// 1. If RevenueCat has returned a result, use that (most authoritative).
/// 2. Fall back to the Firebase RTDB profile value while RevenueCat is loading.
/// 3. Return `false` on any error.
final isProProvider = Provider<bool>((ref) {
  // Check RevenueCat first (authoritative, but async).
  final rcAsync = ref.watch(revenueCatProProvider);

  // Firebase profile fallback.
  final profileAsync = ref.watch(userProfileProvider);
  final firebaseIsPro = profileAsync.when(
    data: (p) => p?.isPro ?? false,
    loading: () => false,
    error: (_, __) => false,
  );

  return rcAsync.when(
    data: (isPro) => isPro,
    // While RevenueCat is loading, defer to Firebase RTDB.
    loading: () => firebaseIsPro,
    // On RC error, defer to Firebase RTDB.
    error: (_, __) => firebaseIsPro,
  );
});

// ── Derived providers ─────────────────────────────────────────────────────────

/// The subscription tier string ('free' | 'pro').
final subscriptionTierProvider = Provider<String>((ref) {
  return ref.watch(isProProvider) ? 'pro' : 'free';
});

/// Daily AI-chat limit based on the user's subscription tier.
///
/// Free → 3 chats/day, Pro → effectively unlimited (9999).
final dailyChatLimitProvider = Provider<int>((ref) {
  final isPro = ref.watch(isProProvider);
  return isPro ? 9999 : 3;
});
