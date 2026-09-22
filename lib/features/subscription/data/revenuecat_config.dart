/// RevenueCat SDK configuration.
///
/// The PUBLIC SDK keys are safe to ship in the client (they're designed to live
/// in the app binary), but we still inject them at build time via --dart-define
/// rather than hardcoding, so they're easy to rotate and stay out of source.
///
/// Build/run with:
///   flutter build appbundle \
///     --dart-define=REVENUECAT_ANDROID_KEY=goog_xxx \
///     --dart-define=REVENUECAT_IOS_KEY=appl_xxx
///
/// In CI these come from GitHub Secrets. Until the keys exist (RevenueCat
/// Phase D3), they default to empty — the app still builds and ships the
/// billing library (which is what unblocks Play's "create subscription" gate);
/// RevenueCat init is simply skipped when the key is empty (see
/// SubscriptionService.init), so nothing crashes and no paywall is shown.
class RevenueCatConfig {
  const RevenueCatConfig._();

  static const String androidKey =
      String.fromEnvironment('REVENUECAT_ANDROID_KEY', defaultValue: '');
  static const String iosKey =
      String.fromEnvironment('REVENUECAT_IOS_KEY', defaultValue: '');

  /// Entitlement identifiers configured in RevenueCat (must match the backend
  /// and the dashboard — see subscription_setup_checklist.md Phase D2).
  static const String entitlementPlus = 'plus';
  static const String entitlementPro = 'pro';

  /// Store product identifiers (must match both stores + RevenueCat).
  static const String productPlusMonthly = 'secbizcard_plus_monthly';
  static const String productProMonthly = 'secbizcard_pro_monthly';
}
