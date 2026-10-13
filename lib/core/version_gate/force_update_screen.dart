import 'package:flutter/material.dart';

import 'package:secbizcard/generated/l10n/app_localizations.dart';
import 'store_launcher.dart';

/// Full-screen, NON-DISMISSIBLE update wall shown when the running build is
/// below `min_supported_build`. Rendered OVER the app at the root (via
/// MaterialApp.router's builder) so a force-blocked user never reaches a route.
///
/// NOT dismissible: the system back button is blocked ([PopScope] canPop:
/// false), there is no AppBar/close affordance, and the only action opens the
/// store. No version/build numbers are shown.
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.system_update,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.versionGateUpdateTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.versionGateUpdateBody,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: launchStore,
                    child: Text(l10n.versionGateUpdateAction),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
