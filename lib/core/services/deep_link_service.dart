import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:play_install_referrer/play_install_referrer.dart';

part 'deep_link_service.g.dart';

/// Provides the pending handshake session ID from deferred deep linking
@riverpod
class PendingHandshakeSession extends _$PendingHandshakeSession {
  static const _pendingSessionKey = 'pending_handshake_session';

  @override
  Future<String?> build() async {
    // Check for saved pending session from install referrer
    final prefs = await SharedPreferences.getInstance();
    final pendingSession = prefs.getString(_pendingSessionKey);

    if (pendingSession != null) {
      // Clear it after reading so it's only used once
      await prefs.remove(_pendingSessionKey);
      return pendingSession;
    }

    return null;
  }

  /// Save a pending session to be retrieved after login
  Future<void> savePendingSession(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingSessionKey, sessionId);
    state = AsyncData(sessionId);
  }

  /// Clear pre-saved pending session
  Future<void> clearPendingSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingSessionKey);
    state = const AsyncData(null);
  }
}

/// Service to handle deep links and install referrer
@riverpod
class DeepLinkService extends _$DeepLinkService {
  late final AppLinks _appLinks;
  StreamSubscription? _linkSubscription;

  @override
  Stream<Uri?> build() {
    if (kIsWeb) {
      // Web doesn't use this service
      return Stream.value(null);
    }

    _appLinks = AppLinks();

    // Check for initial link (app opened via deep link)
    _checkInitialLink();

    // Check for install referrer on first launch (Android only)
    _checkInstallReferrer();

    // Check clipboard for copied Universal Links (iOS deferred deep linking)
    _checkClipboardForDeferredLink();

    // Listen for incoming links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      // Will be handled by GoRouter's deep link integration
    });

    ref.onDispose(() {
      _linkSubscription?.cancel();
    });

    return _appLinks.uriLinkStream;
  }

  Future<void> _checkInitialLink() async {
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        // Handle initial deep link - extract session ID if present
        final sessionId = _extractSessionId(initialLink);
        if (sessionId != null) {
          // Save for after login
          await ref
              .read(pendingHandshakeSessionProvider.notifier)
              .savePendingSession(sessionId);
        }
      }
    } catch (e) {
      // Failed to get initial link, ignore
    }
  }

  Future<void> _checkInstallReferrer() async {
    if (!Platform.isAndroid) return;

    try {
      // Check if this is a first launch by checking shared preferences
      final prefs = await SharedPreferences.getInstance();
      final hasCheckedReferrer =
          prefs.getBool('has_checked_install_referrer') ?? false;

      if (hasCheckedReferrer) return;

      // Mark as checked
      await prefs.setBool('has_checked_install_referrer', true);

      // Get install referrer using Play Install Referrer API
      final referrerDetails = await PlayInstallReferrer.installReferrer;

      if (referrerDetails.installReferrer != null) {
        final referrerString = referrerDetails.installReferrer!;

        // Parse the referrer string to extract session ID
        // Format: utm_source=web&utm_medium=handshake&session=ABC123
        final sessionId = _extractSessionFromReferrer(referrerString);

        if (sessionId != null) {
          await ref
              .read(pendingHandshakeSessionProvider.notifier)
              .savePendingSession(sessionId);
        }
      }
    } catch (e) {
      // Failed to check referrer, ignore
      // This can happen on non-Google Play devices or debug builds
    }
  }

  Future<void> _checkClipboardForDeferredLink() async {
    if (!Platform.isIOS) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final hasCheckedClipboard =
          prefs.getBool('has_checked_clipboard_referrer') ?? false;

      if (hasCheckedClipboard) return;
      await prefs.setBool('has_checked_clipboard_referrer', true);

      // Read clipboard
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData != null && clipboardData.text != null && clipboardData.text!.isNotEmpty) {
        final text = clipboardData.text!;
        final uri = Uri.tryParse(text);
        if (uri != null) {
          final sessionId = _extractSessionId(uri);
          if (sessionId != null) {
            // Clear clipboard to avoid reusing it later unintentionally
            await Clipboard.setData(const ClipboardData(text: ''));
            // Save pending session
            await ref
                .read(pendingHandshakeSessionProvider.notifier)
                .savePendingSession(sessionId);
          }
        }
      }
    } catch (e) {
      // Ignore errors (e.g. user denied paste permission)
    }
  }

  /// Extract session ID from Play Store referrer string
  String? _extractSessionFromReferrer(String referrer) {
    try {
      // Decode the referrer string
      final decoded = Uri.decodeComponent(referrer);

      // Parse as query parameters
      final params = Uri.splitQueryString(decoded);

      // Look for 'session' parameter
      final sessionId = params['session'];

      // Validate it's a 6-char alphanumeric session ID
      if (sessionId != null &&
          sessionId.length == 6 &&
          RegExp(r'^[a-zA-Z0-9]+$').hasMatch(sessionId)) {
        return sessionId;
      }
    } catch (e) {
      // Failed to parse referrer
    }
    return null;
  }

  /// Extract session ID from various URL formats
  String? _extractSessionId(Uri uri) {
    // Format 1: secbizcard://handshake/ABC123
    if (uri.scheme == 'secbizcard' && uri.host == 'handshake') {
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        return pathSegments.first;
      }
    }

    // Format 2: https://ixo.app/ABC123
    if (uri.host == 'ixo.app') {
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        final sessionId = pathSegments.first;
        // Validate it's a 6-char session ID
        if (sessionId.length == 6 &&
            RegExp(r'^[a-zA-Z0-9]+$').hasMatch(sessionId)) {
          return sessionId;
        }
      }
    }

    // Format 3: https://ixo.app/handshake/ABC123
    if (uri.host == 'ixo.app' && uri.path.startsWith('/handshake/')) {
      final pathSegments = uri.pathSegments;
      if (pathSegments.length >= 2) {
        return pathSegments[1];
      }
    }

    return null;
  }
}
