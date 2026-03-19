import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SecBizCard'),
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
              'Your Business Card',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            const Text('Scan to exchange'),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () => context.push('/qr-display'),
              icon: const Icon(Icons.share),
              label: const Text('Share My Info'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.push('/qr-scanner'),
              child: const Text('Scan QR Code'),
            ),
          ],
        ),
      ),
    );
  }
}
