import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'revenuecat_config.dart';

/// The active paid tier as reported by RevenueCat entitlements (client-side
/// read, for UI only — the server-side truth for quota gating is the Firestore
/// field written by the webhook).
enum SubscriptionTier { none, plus, pro }

/// Thin wrapper over the RevenueCat SDK. Handles init (keyed on the Firebase
/// uid so entitlements map to our accounts), fetching the current offering for
/// the paywall, purchasing, restoring, and reading the active entitlement.
///
/// SAFETY: if the SDK key is empty (keys not provisioned yet) or the platform
/// is unsupported, [isConfigured] stays false and every method no-ops/returns
/// empty. The app still builds and ships the billing library (unblocking Play's
/// subscription gate) without showing a broken paywall.
class SubscriptionService {
  SubscriptionService();

  bool _configured = false;
  bool get isConfigured => _configured;

  /// Initialize RevenueCat with the given Firebase uid as the app-user-id.
  /// Idempotent-ish: safe to call again after auth changes (logs in the uid).
  Future<void> init({required String? firebaseUid}) async {
    final key = _platformKey();
    if (key.isEmpty) {
      // Keys not provisioned yet (Phase D3). Skip — no paywall, no crash.
      _configured = false;
      return;
    }
    try {
      await Purchases.setLogLevel(
          kDebugMode ? LogLevel.debug : LogLevel.warn);
      final config = PurchasesConfiguration(key)..appUserID = firebaseUid;
      await Purchases.configure(config);
      _configured = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[RevenueCat] configure failed: $e');
      _configured = false;
    }
  }

  /// Associate the current RevenueCat user with a Firebase uid so purchases and
  /// webhook `app_user_id` map to our account.
  ///
  /// CRITICAL: [init] runs at app startup, often before Firebase auth has
  /// restored the session, so `appUserID` is null there and RevenueCat falls
  /// back to an anonymous id ($RCAnonymousID:...). If we never re-associate, a
  /// purchase is attached to that anonymous id, the webhook writes
  /// users/{anonId} (not users/{firebaseUid}), and resolveTier — which reads
  /// users/{request.auth.uid} — never sees the subscription, so the tier stays
  /// "basic" forever. Calling this on sign-in fixes the mapping. No-op when not
  /// configured or when RevenueCat is already on this uid.
  Future<void> logIn(String firebaseUid) async {
    if (!_configured) return;
    try {
      final current = await Purchases.appUserID;
      if (current == firebaseUid) return; // already mapped
      await Purchases.logIn(firebaseUid);
      if (kDebugMode) debugPrint('[RevenueCat] logIn → $firebaseUid');
    } catch (e) {
      if (kDebugMode) debugPrint('[RevenueCat] logIn failed: $e');
    }
  }

  /// Reset RevenueCat back to an anonymous id on sign-out, so the next user who
  /// signs in on this device doesn't inherit the previous user's entitlements.
  /// No-op when not configured.
  Future<void> logOut() async {
    if (!_configured) return;
    try {
      // Already anonymous → logOut throws; guard by checking first.
      final isAnon = await Purchases.isAnonymous;
      if (isAnon) return;
      await Purchases.logOut();
      if (kDebugMode) debugPrint('[RevenueCat] logOut → anonymous');
    } catch (e) {
      if (kDebugMode) debugPrint('[RevenueCat] logOut failed: $e');
    }
  }

  /// The default offering (the set of packages the paywall shows). Null when
  /// not configured or no offering is available (e.g. store products not
  /// created yet — Phase C).
  Future<Offering?> fetchCurrentOffering() async {
    if (!_configured) return null;
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current;
    } catch (e) {
      if (kDebugMode) debugPrint('[RevenueCat] getOfferings failed: $e');
      return null;
    }
  }

  /// Purchase a package. Returns the resulting active tier. Throws on real
  /// purchase errors so the UI can distinguish user-cancel from failure.
  Future<SubscriptionTier> purchase(Package package) async {
    if (!_configured) return SubscriptionTier.none;
    final result = await Purchases.purchase(PurchaseParams.package(package));
    return _tierFromCustomerInfo(result.customerInfo);
  }

  /// Restore previous purchases (required by App Store review). Returns the
  /// active tier after restore.
  Future<SubscriptionTier> restore() async {
    if (!_configured) return SubscriptionTier.none;
    final info = await Purchases.restorePurchases();
    return _tierFromCustomerInfo(info);
  }

  /// Register a listener fired whenever RevenueCat's [CustomerInfo] changes —
  /// e.g. a purchase completes, a subscription renews/expires, or an
  /// entitlement changes from another device/store. No-ops when not configured.
  /// Returns the same [listener] so callers can remove it later.
  CustomerInfoUpdateListener? addCustomerInfoListener(
      CustomerInfoUpdateListener listener) {
    if (!_configured) return null;
    Purchases.addCustomerInfoUpdateListener(listener);
    return listener;
  }

  /// Removes a previously-added [CustomerInfo] listener. No-ops when not
  /// configured or when [listener] is null.
  void removeCustomerInfoListener(CustomerInfoUpdateListener? listener) {
    if (!_configured || listener == null) return;
    Purchases.removeCustomerInfoUpdateListener(listener);
  }

  /// Read the current active entitlement tier (for UI display).
  Future<SubscriptionTier> currentTier() async {
    if (!_configured) return SubscriptionTier.none;
    try {
      final info = await Purchases.getCustomerInfo();
      return _tierFromCustomerInfo(info);
    } catch (e) {
      if (kDebugMode) debugPrint('[RevenueCat] getCustomerInfo failed: $e');
      return SubscriptionTier.none;
    }
  }

  SubscriptionTier _tierFromCustomerInfo(CustomerInfo info) {
    final active = info.entitlements.active;
    // Pro takes precedence over Plus if both are somehow active.
    if (active.containsKey(RevenueCatConfig.entitlementPro)) {
      return SubscriptionTier.pro;
    }
    if (active.containsKey(RevenueCatConfig.entitlementPlus)) {
      return SubscriptionTier.plus;
    }
    return SubscriptionTier.none;
  }

  String _platformKey() {
    if (kIsWeb) return ''; // web not targeted for purchases here
    if (Platform.isIOS || Platform.isMacOS) return RevenueCatConfig.iosKey;
    if (Platform.isAndroid) return RevenueCatConfig.androidKey;
    return '';
  }
}
