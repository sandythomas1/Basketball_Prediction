import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'app_config.dart';

/// Result returned by [SubscriptionService.purchasePackage] and
/// [SubscriptionService.restorePurchases].
class SubscriptionResult {
  final bool success;
  final bool isPro;
  final String? error;

  const SubscriptionResult({
    required this.success,
    required this.isPro,
    this.error,
  });
}

/// Wraps the RevenueCat `purchases_flutter` SDK with all subscription logic
/// needed by Signal Sports.
///
/// Call [initialize] once at app startup (after Firebase.initializeApp).
class SubscriptionService {
  /// Singleton instance.
  static final SubscriptionService instance = SubscriptionService._();
  SubscriptionService._();

  bool _initialized = false;

  // ── Initialization ──────────────────────────────────────────────────────────

  /// Configure RevenueCat. Safe to call multiple times — subsequent calls are
  /// no-ops once initialised.
  Future<void> initialize() async {
    if (_initialized) return;

    await Purchases.setLogLevel(LogLevel.info);
    final config = PurchasesConfiguration(AppConfig.revenueCatAndroidApiKey);
    await Purchases.configure(config);

    // If a Firebase user is already signed in, identify them in RevenueCat so
    // that subscription state is tied to their UID across devices.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await _identifyUser(uid);
    }

    _initialized = true;
  }

  /// Call when a user signs in so RevenueCat can associate their purchase
  /// history with their Firebase UID.
  Future<void> onUserSignedIn(String uid) async {
    if (!_initialized) await initialize();
    await _identifyUser(uid);
  }

  /// Call when a user signs out so RevenueCat resets to an anonymous ID.
  Future<void> onUserSignedOut() async {
    if (!_initialized) return;
    await Purchases.logOut();
  }

  Future<void> _identifyUser(String uid) async {
    try {
      await Purchases.logIn(uid);
    } catch (_) {
      // Non-fatal — RC will still work with the anonymous ID.
    }
  }

  // ── Entitlement checks ──────────────────────────────────────────────────────

  /// Returns `true` if the current user has an active "pro" entitlement.
  Future<bool> isProActive() async {
    if (!_initialized) await initialize();
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active
          .containsKey(AppConfig.rcProEntitlement);
    } catch (_) {
      return false;
    }
  }

  /// Fetch the latest [CustomerInfo] from RevenueCat.
  Future<CustomerInfo?> getCustomerInfo() async {
    if (!_initialized) await initialize();
    try {
      return await Purchases.getCustomerInfo();
    } catch (_) {
      return null;
    }
  }

  // ── Offerings ───────────────────────────────────────────────────────────────

  /// Fetch the RevenueCat offerings configured for this app.
  /// Returns `null` on network / configuration errors.
  Future<Offerings?> getOfferings() async {
    if (!_initialized) await initialize();
    try {
      return await Purchases.getOfferings();
    } catch (_) {
      return null;
    }
  }

  /// Convenience: fetch the monthly and annual [Package]s from the default
  /// offering. Returns a map with keys `'monthly'` and `'annual'`.
  Future<Map<String, Package?>> getProPackages() async {
    final offerings = await getOfferings();
    if (offerings == null) return {'monthly': null, 'annual': null};

    final offering = offerings.current ?? offerings.all[AppConfig.rcDefaultOffering];
    if (offering == null) return {'monthly': null, 'annual': null};

    Package? monthly;
    Package? annual;

    for (final pkg in offering.availablePackages) {
      final id = pkg.storeProduct.identifier;
      if (id == AppConfig.rcMonthlyProductId ||
          pkg.packageType == PackageType.monthly) {
        monthly = pkg;
      } else if (id == AppConfig.rcAnnualProductId ||
          pkg.packageType == PackageType.annual) {
        annual = pkg;
      }
    }

    return {'monthly': monthly, 'annual': annual};
  }

  // ── Purchasing ──────────────────────────────────────────────────────────────

  /// Purchase the given [package].
  ///
  /// On success, syncs the new subscription tier to Firebase RTDB and returns
  /// `SubscriptionResult(success: true, isPro: true)`.
  ///
  /// Returns `SubscriptionResult(success: false, error: ...)` when:
  /// - The user cancels (PurchasesErrorCode.purchaseCancelledError)
  /// - A store error occurs
  Future<SubscriptionResult> purchasePackage(Package package) async {
    if (!_initialized) await initialize();
    try {
      final info = await Purchases.purchasePackage(package);
      final isPro = info.entitlements.active
          .containsKey(AppConfig.rcProEntitlement);
      if (isPro) {
        await syncToFirebase(info);
      }
      return SubscriptionResult(success: true, isPro: isPro);
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        return const SubscriptionResult(
          success: false,
          isPro: false,
          error: 'Purchase cancelled.',
        );
      }
      return SubscriptionResult(
        success: false,
        isPro: false,
        error: e.toString(),
      );
    } catch (e) {
      return SubscriptionResult(
        success: false,
        isPro: false,
        error: e.toString(),
      );
    }
  }

  // ── Restore ─────────────────────────────────────────────────────────────────

  /// Restore previous purchases for the current user (required for App Store /
  /// Play Store compliance).
  Future<SubscriptionResult> restorePurchases() async {
    if (!_initialized) await initialize();
    try {
      final info = await Purchases.restorePurchases();
      final isPro = info.entitlements.active
          .containsKey(AppConfig.rcProEntitlement);
      await syncToFirebase(info);
      return SubscriptionResult(success: true, isPro: isPro);
    } catch (e) {
      return SubscriptionResult(
        success: false,
        isPro: false,
        error: e.toString(),
      );
    }
  }

  // ── Firebase sync ────────────────────────────────────────────────────────────

  /// Write the subscription tier and expiry to RTDB under
  /// `users/$uid/subscription` so the rest of the app can read it via
  /// [UserProfile.fromJson].
  Future<void> syncToFirebase(CustomerInfo info) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final isPro = info.entitlements.active.containsKey(AppConfig.rcProEntitlement);
    final entitlement = info.entitlements.active[AppConfig.rcProEntitlement];
    final expiryStr = entitlement?.expirationDate;

    int? expiryMs;
    if (expiryStr != null) {
      final parsed = DateTime.tryParse(expiryStr);
      expiryMs = parsed?.millisecondsSinceEpoch;
    }

    final ref = FirebaseDatabase.instance.ref('users/$uid/subscription');
    await ref.update({
      'tier': isPro ? 'pro' : 'free',
      if (expiryMs != null) 'expiry': expiryMs,
    });
  }
}
