import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secbizcard/core/errors/failure.dart';
import 'package:secbizcard/features/handshake/data/handshake_repository.dart';

void main() {
  group('mapFunctionsError', () {
    test('transient/connectivity codes map to ConnectionFailure(offline)', () {
      for (final code in kConnectivityFunctionCodes) {
        final failure = mapFunctionsError(code, 'UNAVAILABLE');
        expect(failure, isA<ConnectionFailure>(),
            reason: 'code "$code" should be treated as offline');
        expect(failure.message, 'offline');
      }
    });

    test('non-transient codes stay a ServerFailure with code + message', () {
      final failure = mapFunctionsError('unauthenticated', 'Missing token');
      expect(failure, isA<ServerFailure>());
      expect(failure.message, 'unauthenticated: Missing token');
    });

    test('null message falls back to "Unknown error" for ServerFailure', () {
      final failure = mapFunctionsError('invalid-argument', null);
      expect(failure, isA<ServerFailure>());
      expect(failure.message, 'invalid-argument: Unknown error');
    });
  });

  group('mapGenericError', () {
    test('SocketException maps to ConnectionFailure(offline)', () {
      final failure = mapGenericError(const SocketException('no route'));
      expect(failure, isA<ConnectionFailure>());
      expect(failure.message, 'offline');
    });

    test('a failed host lookup string maps to offline', () {
      final failure =
          mapGenericError(Exception('Failed host lookup: us-central1'));
      expect(failure, isA<ConnectionFailure>());
      expect(failure.message, 'offline');
    });

    test('an unrelated error stays a ServerFailure', () {
      final failure = mapGenericError(Exception('boom'));
      expect(failure, isA<ServerFailure>());
      expect(failure.message, contains('boom'));
    });
  });
}
