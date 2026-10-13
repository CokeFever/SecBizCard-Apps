import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the platform app store page for SecBizCard so the user can update.
///
/// Both platforms open EXTERNALLY ([LaunchMode.externalApplication]):
///   - Android: try `market://` (opens the Play Store app directly); if that
///     can't be launched (no Play Store, e.g. some devices), fall back to the
///     https Play Store URL.
///   - iOS: the App Store product page.
///
/// Any failure is swallowed/logged — a store launch that fails must never crash
/// the gate (the force wall stays up; the user can retry the button).
Future<void> launchStore() async {
  try {
    if (Platform.isAndroid) {
      final market = Uri.parse('market://details?id=app.ixo.secbizcard');
      final web = Uri.parse(
          'https://play.google.com/store/apps/details?id=app.ixo.secbizcard');
      if (await canLaunchUrl(market)) {
        final ok =
            await launchUrl(market, mode: LaunchMode.externalApplication);
        if (ok) return;
      }
      await launchUrl(web, mode: LaunchMode.externalApplication);
    } else if (Platform.isIOS) {
      final appStore = Uri.parse('https://apps.apple.com/app/id6759779351');
      await launchUrl(appStore, mode: LaunchMode.externalApplication);
    }
  } catch (e) {
    debugPrint('[VersionGate] launchStore failed (continuing): $e');
  }
}
