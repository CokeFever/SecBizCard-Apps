import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:secbizcard/features/auth/data/auth_repository.dart';
import 'package:secbizcard/features/profile/data/profile_repository.dart';
import 'package:secbizcard/features/handshake/data/handshake_history_repository.dart';

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

    // 5. Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('[NotificationService] Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      // If it's a handshake request, log it to history!
      if (message.data['type'] == 'handshake_request') {
        final sessionId = message.data['sessionId'];
        final payloadJson = message.data['payload'];
        
        if (sessionId != null && payloadJson != null) {
          final data = jsonDecode(payloadJson) as Map<String, dynamic>;
          final senderProfile = data['receiverProfile'] as Map<String, dynamic>?;
          
          final historyRepo = _ref.read(handshakeHistoryRepositoryProvider);
          await historyRepo.logRequest(
            HandshakeHistoryRecord(
              sessionId: sessionId,
              senderUid: senderProfile?['uid'],
              senderName: senderProfile?['displayName'],
              photoUrl: senderProfile?['photoUrl'],
              status: HandshakeRequestStatus.pending,
              timestamp: DateTime.now(),
              receiverProfileJson: payloadJson,
            ),
          );
          
          // Invalidate counts so badge updates
          _ref.invalidate(pendingHandshakeCountProvider);
          _ref.invalidate(handshakeHistoryProvider);
        }
      }
    });

    // 5. Handle background/terminated state messages when app is opened
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[NotificationService] Message clicked/opened app!');
    });
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
