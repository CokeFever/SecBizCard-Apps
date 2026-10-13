import 'package:flutter/material.dart';

import 'package:secbizcard/generated/l10n/app_localizations.dart';
import 'store_launcher.dart';

/// Shows the dismissible "update available" soft alert.
///
/// Used when the running build is at/above `min_supported_build` but below
/// `latest_build`. The user may continue ("Later") or open the store
/// ("Update"). Follows the app's `showDialog` + `AppLocalizations.of(context)!`
/// convention. Caller is responsible for showing this at most once per launch.
Future<void> showSoftUpdateAlert(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.versionGateUpdateTitle),
      content: Text(l10n.versionGateUpdateBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.versionGateLaterAction),
        ),
        TextButton(
          onPressed: () {
            launchStore();
            Navigator.of(context).pop();
          },
          child: Text(l10n.versionGateUpdateAction),
        ),
      ],
    ),
  );
}
