import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'subscription_service.dart';

part 'subscription_providers.g.dart';

/// The singleton RevenueCat wrapper. keepAlive so init runs once and the
/// configured SDK state persists across the app.
@Riverpod(keepAlive: true)
SubscriptionService subscriptionService(Ref ref) {
  return SubscriptionService();
}
