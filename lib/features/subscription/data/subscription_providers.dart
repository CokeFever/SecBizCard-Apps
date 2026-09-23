import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:secbizcard/features/contacts/data/ocr_usage_provider.dart';
import 'subscription_service.dart';

part 'subscription_providers.g.dart';

/// The singleton RevenueCat wrapper. keepAlive so init runs once and the
/// configured SDK state persists across the app.
@Riverpod(keepAlive: true)
SubscriptionService subscriptionService(Ref ref) {
  return SubscriptionService();
}

/// Bridges RevenueCat entitlement changes to the OCR usage cache: whenever the
/// customer's [CustomerInfo] changes (purchase completes, subscription
/// renews/expires, or an entitlement changes from another device), we refresh
/// [ocrUsageNotifierProvider] so the displayed tier re-syncs with the backend
/// (the webhook updates the backend tier; this just re-fetches it).
///
/// keepAlive + eagerly initialized at startup so the listener is registered for
/// the whole session. Cleans itself up on dispose.
@Riverpod(keepAlive: true)
void subscriptionSync(Ref ref) {
  final service = ref.watch(subscriptionServiceProvider);
  final listener = service.addCustomerInfoListener((_) {
    // Entitlement changed → re-fetch the backend tier/usage.
    ref.read(ocrUsageNotifierProvider.notifier).refresh();
  });
  ref.onDispose(() => service.removeCustomerInfoListener(listener));
}
