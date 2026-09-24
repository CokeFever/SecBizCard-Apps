/// Canonical external links for the app (privacy policy, EULA, store pages).
///
/// SINGLE SOURCE OF TRUTH — every screen that opens these must reference these
/// constants, never a hardcoded string. Historically the privacy/EULA URLs were
/// duplicated across the landing footer, the drawer, and the paywall, and drifted
/// apart (the landing page kept the old ".html" form that 404s). Centralizing
/// them here means a future path change is a one-line edit.
///
/// NOTE: the canonical pages are extensionless (`/privacy`, `/eula`). The old
/// `.html` variants return 404 and must not be used.
class AppLinks {
  AppLinks._();

  /// Privacy Policy (ixo.app).
  static const String privacyPolicy = 'https://ixo.app/privacy';

  /// End User License Agreement / Terms of Use (ixo.app).
  static const String eula = 'https://ixo.app/eula';
}
