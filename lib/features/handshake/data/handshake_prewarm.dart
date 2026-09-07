import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:secbizcard/features/handshake/data/handshake_repository.dart';
import 'package:secbizcard/features/handshake/data/handshake_session.dart';

part 'handshake_prewarm.g.dart';

/// Holds a speculatively pre-generated handshake session so the Share screen
/// can display a QR code almost instantly instead of waiting for a Cloud
/// Function round-trip.
///
/// Flow:
///  - After login (entering /home), [prewarm] is fired in the background.
///  - When QrDisplayScreen opens, it calls [consume]; if a warm session is
///    ready it is returned immediately (and cleared so it's used only once).
///  - The QR's countdown is still driven by the session document's server
///    `expiresAt`, so a pre-warmed session shows its true remaining time.
///
/// Only the default (non-batch) session is pre-warmed, matching the Share
/// screen's initial state (`batchApproval = false`).
@Riverpod(keepAlive: true)
class HandshakePrewarm extends _$HandshakePrewarm {
  bool _inFlight = false;

  @override
  HandshakeSession? build() => null;

  /// Fire-and-forget background generation. Safe to call multiple times; it
  /// no-ops if a warm session already exists or one is being created.
  void prewarm() {
    if (state != null || _inFlight) return;
    _inFlight = true;
    Future(() async {
      final repo = ref.read(handshakeRepositoryProvider);
      final result = await repo.createHandshakeSession(batchApproval: false);
      result.fold(
        (failure) {
          debugPrint('[Prewarm] session pre-generation failed: ${failure.message}');
        },
        (session) {
          debugPrint('[Prewarm] session ready: ${session.sessionId}');
          state = session;
        },
      );
      _inFlight = false;
    });
  }

  /// Returns the pre-warmed session (if any) and clears it so it is used once.
  HandshakeSession? consume() {
    final s = state;
    state = null;
    return s;
  }
}
