import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:secbizcard/core/router/app_router.dart';
import 'package:secbizcard/features/auth/data/auth_repository.dart';
import 'package:secbizcard/features/profile/data/profile_repository.dart';
import 'package:secbizcard/features/handshake/data/handshake_history_repository.dart';
import 'package:secbizcard/features/handshake/data/handshake_repository.dart';

part 'notification_service.g.dart';

@riverpod
NotificationService notificationService(Ref ref) {
  return NotificationService(ref);
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `Firebase.initializeApp()` first.
  debugPrint("Handling a background message: ${message.messageId}");
}

class NotificationService {
  final Ref _ref;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  String? _lastToken;

  NotificationService(this._ref);

  Future<void> initialize() async {
    // 0. Set background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 1. Request permissions (iOS/Android 13+)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('[NotificationService] User granted permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('[NotificationService] User granted provisional permission');
    } else {
      debugPrint('[NotificationService] User declined or has not accepted permission');
    }

    // Enable foreground notifications
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Handle token refresh
    _fcm.onTokenRefresh.listen(_updateToken);

    // 3. Initial token fetch
    final token = await _fcm.getToken();
    if (token != null) {
      _lastToken = token;
      await _updateToken(token);
    }

    // 4. Listen to Auth State to sync token when user logs in
    _ref.listen(authStateProvider, (previous, next) async {
      final user = next.valueOrNull;
      if (user != null && _lastToken != null) {
        debugPrint('[NotificationService] Auth state changed: Syncing token to Firestore');
        await _updateToken(_lastToken!);
      }
    });

    // 5. Handle foreground messages — log the incoming handshake so the bell
    //    badge + Notifications list update even when the user is not on the
    //    Share screen.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('[NotificationService] Foreground message: ${message.data}');
      await _logHandshakeFromMessage(message);
    });

    // 6. App opened by TAPPING a notification (from background). Log it, then
    //    deep-link the creator straight into the approval flow.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      debugPrint('[NotificationService] Notification tapped: ${message.data}');
      await _logHandshakeFromMessage(message);
      _routeFromMessage(message);
    });

    // 7. App launched from TERMINATED state by tapping a notification.
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[NotificationService] Launched from notification: ${initialMessage.data}');
      await _logHandshakeFromMessage(initialMessage);
      _routeFromMessage(initialMessage);
    }
  }

  /// Case-insensitive handshake type check.
  bool _isType(RemoteMessage m, String type) =>
      (m.data['type'] as String?)?.toUpperCase() == type.toUpperCase();

  /// Logs an incoming handshake push into the local history so the in-app
  /// Notifications list + bell badge reflect it. Works for both a fresh request
  /// (writes a pending row) and a returned-info event. Resilient to missing
  /// requester metadata: uses the `requester` summary in the push data when
  /// present, otherwise falls back to reading the session document. Never
  /// throws — a logging failure must not break notification handling.
  Future<void> _logHandshakeFromMessage(RemoteMessage message) async {
    try {
      final isRequest = _isType(message, 'HANDSHAKE_REQUEST');
      final isReturn = _isType(message, 'HANDSHAKE_RETURN');
      if (!isRequest && !isReturn) return;

      final sessionId = message.data['sessionId'] as String?;
      if (sessionId == null || sessionId.isEmpty) return;

      // Requester summary: prefer the compact `requester` JSON now sent in the
      // push data; fall back to the session doc's receiverProfile.
      Map<String, dynamic>? requester;
      final requesterRaw = message.data['requester'] as String?;
      if (requesterRaw != null && requesterRaw.isNotEmpty) {
        try {
          requester = jsonDecode(requesterRaw) as Map<String, dynamic>;
        } catch (_) {/* ignore malformed */}
      }
      if (requester == null) {
        try {
          final repo = _ref.read(handshakeRepositoryProvider);
          final snap = await repo.listenToSession(sessionId).first
              .timeout(const Duration(seconds: 5));
          final data = snap.data();
          final rp = data?['receiverProfile'] as Map<String, dynamic>?;
          if (rp != null) requester = rp;
        } catch (_) {/* offline / not accessible — log without profile */}
      }

      final historyRepo = _ref.read(handshakeHistoryRepositoryProvider);
      await historyRepo.logRequest(
        HandshakeHistoryRecord(
          sessionId: sessionId,
          senderUid: requester?['uid'] as String?,
          senderName: requester?['displayName'] as String?,
          photoUrl: requester?['photoUrl'] as String?,
          // A returned-info event means the exchange completed; a request is
          // still pending the creator's approval.
          status: isReturn
              ? HandshakeRequestStatus.approved
              : HandshakeRequestStatus.pending,
          timestamp: DateTime.now(),
        ),
      );

      _ref.invalidate(pendingHandshakeCountProvider);
      _ref.invalidate(handshakeHistoryProvider);
    } catch (e) {
      debugPrint('[NotificationService] Failed to log handshake from push: $e');
    }
  }

  /// After a tapped/launched handshake-request notification, deep-link the
  /// creator into the approval flow for that specific session.
  void _routeFromMessage(RemoteMessage message) {
    if (!_isType(message, 'HANDSHAKE_REQUEST')) return;
    final sessionId = message.data['sessionId'] as String?;
    if (sessionId == null || sessionId.isEmpty) return;
    try {
      _ref.read(goRouterProvider).push('/incoming-handshake/$sessionId');
    } catch (e) {
      debugPrint('[NotificationService] Failed to route to approval: $e');
    }
  }

  Future<void> _updateToken(String token) async {
    _lastToken = token;
    debugPrint('[NotificationService] FCM Token: $token');
    
    final user = _ref.read(authStateProvider).valueOrNull;
    if (user != null) {
      final profileRepo = _ref.read(profileRepositoryProvider);
      await profileRepo.updateFcmToken(user.uid, token);
      debugPrint('[NotificationService] Token saved for user ${user.uid}');
    }
  }
}
