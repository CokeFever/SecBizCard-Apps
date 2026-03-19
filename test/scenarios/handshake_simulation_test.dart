import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:secbizcard/core/errors/failure.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';

/// Handshake Simulation Test
///
/// This test simulates the handshake flow logic without widget testing,
/// since DocumentSnapshot from Firestore cannot be mocked (sealed class).
///
/// Flow: A creates session -> B joins & requests -> A approves -> B saves

// --- Test Doubles ---

/// Simulates the handshake session data store (in-memory Firestore mock)
class FakeHandshakeStore {
  final Map<String, Map<String, dynamic>> sessions = {};
  final Map<String, StreamController<Map<String, dynamic>>> _listeners = {};

  String createSession(String ownerId) {
    const sessionId = 'session_123';
    sessions[sessionId] = {
      'ownerId': ownerId,
      'status': 'WAITING',
      'createdAt': DateTime.now().toIso8601String(),
    };
    _listeners[sessionId] = StreamController.broadcast();
    return sessionId;
  }

  Either<Failure, Unit> requestHandshake(
    String sessionId,
    Map<String, dynamic> receiverProfile,
  ) {
    if (!sessions.containsKey(sessionId)) {
      return left(const ServerFailure('Session not found'));
    }

    sessions[sessionId]!['status'] = 'REQUESTED';
    sessions[sessionId]!['receiverProfile'] = receiverProfile;
    _notifyListeners(sessionId);
    return right(unit);
  }

  Either<Failure, Unit> respondToHandshake(
    String sessionId, {
    required bool accept,
    Map<String, dynamic>? payload,
  }) {
    if (!sessions.containsKey(sessionId)) {
      return left(const ServerFailure('Session not found'));
    }

    sessions[sessionId]!['status'] = accept ? 'APPROVED' : 'REJECTED';
    if (accept && payload != null) {
      sessions[sessionId]!['payload'] = payload;
    }
    _notifyListeners(sessionId);
    return right(unit);
  }

  Either<Failure, Unit> returnHandshake(
    String sessionId,
    Map<String, dynamic> returnPayload,
  ) {
    if (!sessions.containsKey(sessionId)) {
      return left(const ServerFailure('Session not found'));
    }

    sessions[sessionId]!['returnPayload'] = returnPayload;
    sessions[sessionId]!['status'] = 'COMPLETED';
    _notifyListeners(sessionId);
    return right(unit);
  }

  Stream<Map<String, dynamic>> listenToSession(String sessionId) {
    if (!_listeners.containsKey(sessionId)) {
      _listeners[sessionId] = StreamController.broadcast();
    }
    // Emit initial state
    if (sessions.containsKey(sessionId)) {
      Future.microtask(() => _notifyListeners(sessionId));
    }
    return _listeners[sessionId]!.stream;
  }

  void _notifyListeners(String sessionId) {
    if (_listeners.containsKey(sessionId) && sessions.containsKey(sessionId)) {
      _listeners[sessionId]!.add(Map.from(sessions[sessionId]!));
    }
  }

  void dispose() {
    for (final controller in _listeners.values) {
      controller.close();
    }
  }
}

// --- The Test ---

void main() {
  late FakeHandshakeStore handshakeStore;

  final profileA = UserProfile(
    uid: 'user_a_uid',
    email: 'user.a@example.com',
    displayName: 'User A',
    createdAt: DateTime.now(),
    emailVerified: true,
  );

  final profileB = UserProfile(
    uid: 'user_b_uid',
    email: 'user.b@example.com',
    displayName: 'User B',
    createdAt: DateTime.now(),
    emailVerified: true,
  );

  setUp(() {
    handshakeStore = FakeHandshakeStore();
  });

  tearDown(() {
    handshakeStore.dispose();
  });

  test(
    'Handshake Flow: A creates -> B requests -> A approves -> B receives',
    () async {
      // === Step 1: User A creates a handshake session ===
      final sessionId = handshakeStore.createSession(profileA.uid);

      expect(sessionId, equals('session_123'));
      expect(handshakeStore.sessions[sessionId]!['status'], equals('WAITING'));
      expect(
        handshakeStore.sessions[sessionId]!['ownerId'],
        equals('user_a_uid'),
      );

      // === Step 2: User B scans and joins, sends request ===
      // B's perspective: listening to session updates
      final completer = Completer<Map<String, dynamic>>();
      final subscription = handshakeStore.listenToSession(sessionId).listen((
        data,
      ) {
        if (data['status'] == 'APPROVED' && !completer.isCompleted) {
          completer.complete(data);
        }
      });

      // B sends request with their limited profile
      final requestResult = handshakeStore.requestHandshake(sessionId, {
        'displayName': profileB.displayName,
        'email': profileB.email,
      });

      expect(requestResult.isRight(), isTrue);
      expect(
        handshakeStore.sessions[sessionId]!['status'],
        equals('REQUESTED'),
      );
      expect(
        handshakeStore.sessions[sessionId]!['receiverProfile']['displayName'],
        equals('User B'),
      );

      // === Step 3: User A sees request and approves ===
      // A's perspective: sees B's request, decides to approve
      final respondResult = handshakeStore.respondToHandshake(
        sessionId,
        accept: true,
        payload: profileA.toJson(),
      );

      expect(respondResult.isRight(), isTrue);
      expect(handshakeStore.sessions[sessionId]!['status'], equals('APPROVED'));

      // === Step 4: User B receives A's profile via stream ===
      final approvedData = await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw TestFailure('Timeout waiting for approval'),
      );

      expect(approvedData['status'], equals('APPROVED'));
      expect(approvedData['payload'], isNotNull);
      expect(approvedData['payload']['displayName'], equals('User A'));
      expect(approvedData['payload']['email'], equals('user.a@example.com'));

      await subscription.cancel();
    },
  );

  test('Handshake Flow: A creates -> B requests -> A rejects', () async {
    // User A creates session
    final sessionId = handshakeStore.createSession(profileA.uid);

    // User B sends request
    handshakeStore.requestHandshake(sessionId, {
      'displayName': profileB.displayName,
    });

    expect(handshakeStore.sessions[sessionId]!['status'], equals('REQUESTED'));

    // User A rejects
    final rejectResult = handshakeStore.respondToHandshake(
      sessionId,
      accept: false,
    );

    expect(rejectResult.isRight(), isTrue);
    expect(handshakeStore.sessions[sessionId]!['status'], equals('REJECTED'));
    expect(handshakeStore.sessions[sessionId]!['payload'], isNull);
  });

  test('Request to non-existent session fails', () {
    final result = handshakeStore.requestHandshake('non_existent_session', {
      'displayName': 'Test',
    });

    expect(result.isLeft(), isTrue);
    result.fold(
      (failure) => expect(failure.message, contains('Session not found')),
      (_) => fail('Expected failure'),
    );
  });

  test(
    'Full bidirectional exchange: A creates -> B requests -> A approves with profile -> B returns profile',
    () async {
      // Step 1: A creates session
      final sessionId = handshakeStore.createSession(profileA.uid);

      // Step 2: B requests
      handshakeStore.requestHandshake(sessionId, profileB.toJson());

      // Step 3: A approves with their profile
      handshakeStore.respondToHandshake(
        sessionId,
        accept: true,
        payload: profileA.toJson(),
      );

      // Step 4: B returns their full profile to A
      final returnResult = handshakeStore.returnHandshake(
        sessionId,
        profileB.toJson(),
      );

      expect(returnResult.isRight(), isTrue);
      expect(
        handshakeStore.sessions[sessionId]!['status'],
        equals('COMPLETED'),
      );
      expect(
        handshakeStore.sessions[sessionId]!['returnPayload']['displayName'],
        equals('User B'),
      );
      expect(
        handshakeStore.sessions[sessionId]!['payload']['displayName'],
        equals('User A'),
      );
    },
  );
}
