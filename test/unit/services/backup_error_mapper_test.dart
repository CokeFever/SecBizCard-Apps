import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import 'package:secbizcard/core/errors/failure.dart';
import 'package:secbizcard/core/services/backup_error_mapper.dart';

void main() {
  group('mapBackupError — interrupted mid-transfer', () {
    test('ClientException with contentLength mismatch → InterruptedTransferFailure',
        () {
      // The exact shape the http/googleapis stack throws when the upload stream
      // delivers fewer bytes than the declared contentLength (the user's
      // "upload cut off mid-transfer" case).
      final e = http.ClientException(
        'Content size below specified contentLength. 1048576 bytes written '
        'but expected 2097152.',
      );
      final failure = mapBackupError(e);
      expect(failure, isA<InterruptedTransferFailure>());
      expect(failure.message, 'interrupted');
    });

    test('connection reset string → InterruptedTransferFailure', () {
      final failure = mapBackupError(
        const SocketException('Connection reset by peer'),
      );
      expect(failure, isA<InterruptedTransferFailure>());
    });

    test('connection closed before full header → InterruptedTransferFailure',
        () {
      final failure =
          mapBackupError(http.ClientException('Connection closed while receiving data'));
      expect(failure, isA<InterruptedTransferFailure>());
    });

    test('broken pipe → InterruptedTransferFailure', () {
      final failure =
          mapBackupError(const SocketException('Broken pipe'));
      expect(failure, isA<InterruptedTransferFailure>());
    });

    test('TimeoutException → InterruptedTransferFailure', () {
      final failure = mapBackupError(TimeoutException('upload stalled'));
      expect(failure, isA<InterruptedTransferFailure>());
    });
  });

  group('mapBackupError — offline (no connectivity)', () {
    test('SocketException "failed host lookup" → ConnectionFailure(offline)',
        () {
      final failure = mapBackupError(
        const SocketException('Failed host lookup: www.googleapis.com'),
      );
      expect(failure, isA<ConnectionFailure>());
      expect(failure.message, 'offline');
    });

    test('network is unreachable → ConnectionFailure(offline)', () {
      final failure =
          mapBackupError(Exception('Network is unreachable'));
      expect(failure, isA<ConnectionFailure>());
      expect(failure.message, 'offline');
    });

    test('connection refused → ConnectionFailure(offline)', () {
      final failure = mapBackupError(Exception('Connection refused'));
      expect(failure, isA<ConnectionFailure>());
    });
  });

  group('mapBackupError — Drive auth / token', () {
    test('DetailedApiRequestError 401 → AuthFailure(re-auth)', () {
      final failure =
          mapBackupError(drive.DetailedApiRequestError(401, 'Invalid Credentials'));
      expect(failure, isA<AuthFailure>());
      expect(failure.message, 'backup_auth');
    });

    test('DetailedApiRequestError 403 → AuthFailure(re-auth)', () {
      final failure = mapBackupError(
        drive.DetailedApiRequestError(403, 'Insufficient Permission'),
      );
      expect(failure, isA<AuthFailure>());
      expect(failure.message, 'backup_auth');
    });

    test('insufficient authentication scopes string → AuthFailure', () {
      final failure = mapBackupError(
        Exception('Request had insufficient authentication scopes.'),
      );
      expect(failure, isA<AuthFailure>());
      expect(failure.message, 'backup_auth');
    });
  });

  group('mapBackupError — generic fallback', () {
    test('an unrelated error → GeneralFailure(generic)', () {
      final failure = mapBackupError(Exception('something odd happened'));
      expect(failure, isA<GeneralFailure>());
      expect(failure.message, 'backup_generic');
    });

    test('a DetailedApiRequestError 500 (server) → generic, not interrupted',
        () {
      // 500 is not an auth code and the message carries no transport keyword,
      // so it falls through to the generic, retryable bucket.
      final failure =
          mapBackupError(drive.DetailedApiRequestError(500, 'Backend Error'));
      expect(failure, isA<GeneralFailure>());
    });
  });

  group('mapBackupError — passthrough of already-typed failures', () {
    test('a WrongMagicWordFailure is returned unchanged', () {
      const original = WrongMagicWordFailure();
      final failure = mapBackupError(original);
      expect(identical(failure, original), isTrue);
    });

    test('an EmptyBackupFailure is returned unchanged', () {
      const original = EmptyBackupFailure();
      final failure = mapBackupError(original);
      expect(identical(failure, original), isTrue);
    });
  });
}
