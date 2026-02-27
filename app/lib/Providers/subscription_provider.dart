import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'user_provider.dart';

/// Whether the current user is on the Pro tier.
///
/// Returns `false` while the profile is still loading, if the user is
/// logged-out, or if they are on the free tier.
final isProProvider = Provider<bool>((ref) {
  final profile = ref.watch(userProfileProvider);
  return profile.when(
    data: (p) => p?.isPro ?? false,
    loading: () => false,
    error: (_, __) => false,
  );
});

/// The subscription tier string ('free' | 'pro').
final subscriptionTierProvider = Provider<String>((ref) {
  final profile = ref.watch(userProfileProvider);
  return profile.when(
    data: (p) => p?.subscriptionTier ?? 'free',
    loading: () => 'free',
    error: (_, __) => 'free',
  );
});

/// Daily AI-chat limit based on the user's subscription tier.
///
/// Free → 3 chats/day, Pro → effectively unlimited (9999).
final dailyChatLimitProvider = Provider<int>((ref) {
  final isPro = ref.watch(isProProvider);
  return isPro ? 9999 : 3;
});
