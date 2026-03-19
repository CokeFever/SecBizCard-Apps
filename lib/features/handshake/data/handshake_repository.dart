import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:secbizcard/core/errors/failure.dart';

part 'handshake_repository.g.dart';

@riverpod
HandshakeRepository handshakeRepository(Ref ref) {
  // Use us-central1 explicitly with the default Firebase app to ensure auth tokens are passed
  return HandshakeRepository(
    FirebaseFunctions.instanceFor(app: Firebase.app(), region: 'us-central1'),
  );
}

class HandshakeRepository {
  final FirebaseFunctions _functions;

  HandshakeRepository(this._functions);

  /// Creates a handshake session and returns the deep link URL with 6-char hash
  Future<Either<Failure, String>> createHandshakeSession({
    bool batchApproval = true,
  }) async {
    try {
      final callable = _functions.httpsCallable('createHandshakeSession');
      // No context needed initially.
      final result = await callable.call({'batchApproval': batchApproval});

      final url = result.data['url'] as String?;
      if (url == null) {
        return left(const ServerFailure('Failed to generate URL'));
      }

      return right(url);
    } on FirebaseFunctionsException catch (e) {
      return left(ServerFailure('${e.code}: ${e.message ?? 'Unknown error'}'));
    } catch (e) {
      return left(ServerFailure(e.toString()));
    }
  }

  /// Receiver sends a request to the Sender
  Future<Either<Failure, Unit>> requestHandshake(
    String sessionId,
    Map<String, dynamic> receiverProfileLimited,
  ) async {
    try {
      final callable = _functions.httpsCallable('requestHandshake');
      await callable.call({
        'sessionId': sessionId,
        'receiverProfile': receiverProfileLimited,
      });
      return right(unit);
    } on FirebaseFunctionsException catch (e) {
      return left(ServerFailure(e.message ?? 'Unknown error'));
    } catch (e) {
      return left(ServerFailure(e.toString()));
    }
  }

  /// Sender responds to the request (Approve/Reject)
  Future<Either<Failure, Unit>> respondToHandshake(
    String sessionId, {
    required bool accept,
    Map<String, dynamic>? encryptedPayload,
  }) async {
    try {
      final callable = _functions.httpsCallable('respondToHandshake');
      await callable.call({
        'sessionId': sessionId,
        'accept': accept,
        if (accept && encryptedPayload != null) 'payload': encryptedPayload,
      });
      return right(unit);
    } on FirebaseFunctionsException catch (e) {
      return left(ServerFailure(e.message ?? 'Unknown error'));
    } catch (e) {
      return left(ServerFailure(e.toString()));
    }
  }

  /// Receiver returns their profile data to the Sender
  Future<Either<Failure, Unit>> returnHandshake(
    String sessionId,
    Map<String, dynamic> returnPayload,
  ) async {
    try {
      final callable = _functions.httpsCallable('returnHandshake');
      await callable.call({'sessionId': sessionId, 'payload': returnPayload});
      return right(unit);
    } on FirebaseFunctionsException catch (e) {
      return left(ServerFailure(e.message ?? 'Unknown error'));
    } catch (e) {
      return left(ServerFailure(e.toString()));
    }
  }

  /// Listen to session status changes (for both Sender and Receiver)
  /// Note: This usually requires Firestore snapshot listener on the session document.
  /// We assume the client can access the session document `handshakes/{sessionId}` directly
  /// or via a callable wrapper if we want to hide Firestore.
  /// Given "Zero Knowledge Server" principle, direct Firestore access with security rules is typical pattern.
  Stream<DocumentSnapshot<Map<String, dynamic>>> listenToSession(
    String sessionId,
  ) {
    return FirebaseFirestore.instance
        .collection('handshakes')
        .doc(sessionId)
        .snapshots();
  }
}
