import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:secbizcard/generated/l10n/app_localizations.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.qr_code, size: 100),
            const SizedBox(height: 20),
            Text(
              l10n.homeYourBusinessCard,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Text(l10n.homeScanToExchange),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () => context.push('/qr-display'),
              icon: const Icon(Icons.share),
              label: Text(l10n.homeShareMyInfo),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.push('/qr-scanner'),
              child: Text(l10n.scannerTitle),
            ),
          ],
        ),
      ),
    );
  }
}
