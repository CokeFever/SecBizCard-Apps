import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:secbizcard/features/auth/data/auth_repository.dart';
import 'package:secbizcard/features/contacts/data/ocr_usage_provider.dart';
import 'subscription_service.dart';

part 'subscription_providers.g.dart';

/// The singleton RevenueCat wrapper. keepAlive so init runs once and the
/// configured SDK state persists across the app.
@Riverpod(keepAlive: true)
SubscriptionService subscriptionService(Ref ref) {
  return SubscriptionService();
}

/// Keeps RevenueCat's app-user-id in sync with the Firebase uid.
///
/// This is the fix for "purchase succeeds but tier never updates": [init] runs
/// at startup before auth restores, so RevenueCat starts anonymous. When the
/// user signs in we [SubscriptionService.logIn] so purchases + webhook
/// `app_user_id` map to the Firebase uid the backend's resolveTier reads. On
/// sign-out we reset to anonymous so the next user starts clean.
///
/// keepAlive + eagerly initialized at startup so the listener is live for the
/// whole session.
@Riverpod(keepAlive: true)
void subscriptionIdentitySync(Ref ref) {
  final service = ref.watch(subscriptionServiceProvider);

  // Fire for the current value AND every subsequent auth change.
  final current = ref.read(authStateProvider).valueOrNull?.uid;
  if (current != null) {
    service.logIn(current);
  }

  ref.listen(authStateProvider, (prev, next) {
    final uid = next.valueOrNull?.uid;
    if (uid != null) {
      service.logIn(uid);
    } else if (prev?.valueOrNull?.uid != null) {
      // Went from signed-in to signed-out.
      service.logOut();
    }
  });
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
