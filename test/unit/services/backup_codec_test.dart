import 'dart:convert';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_test/flutter_test.dart';

import 'package:secbizcard/core/errors/failure.dart';
import 'package:secbizcard/core/services/backup_codec.dart';

/// A deterministic RNG so salt+nonce are reproducible in tests (NEVER use for
/// real crypto). Emits a repeating ramp of bytes.
class _SeqRandom implements Random {
  int _i = 0;
  @override
  int nextInt(int max) => (_i++ % 256) % max;
  @override
  bool nextBool() => nextInt(2) == 1;
  @override
  double nextDouble() => nextInt(1 << 20) / (1 << 20);
}

List<int> _makeZip(Map<String, dynamic> data) {
  final archive = Archive();
  final jsonBytes = utf8.encode(jsonEncode(data));
  archive.addFile(ArchiveFile('data.json', jsonBytes.length, jsonBytes));
  return ZipEncoder().encode(archive);
}

Map<String, dynamic> _readZip(List<int> bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final f = archive.findFile('data.json')!;
  return jsonDecode(utf8.decode(f.content)) as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PBKDF2 key derivation', () {
    test('produces a stable known key for a fixed input + salt', () async {
      // RFC-style fixed vector: password "password", salt = 16 bytes of 0x00,
      // 100000 iterations, 32-byte output. Asserting exact bytes locks the
      // parameters so a future Web Crypto impl must match bit-for-bit.
      final salt = List<int>.filled(16, 0);
      final key = await BackupCodec.deriveKey(keySource: 'password', salt: salt);
      expect(key.length, 32);
      // Precomputed with PBKDF2-HMAC-SHA256(password, 16x0x00, 100000, 32B).
      // Independently verified to match Python's
      // hashlib.pbkdf2_hmac('sha256', b'password', bytes(16), 100000, 32),
      // so a Web Crypto deriveBits with identical params matches bit-for-bit.
      expect(
        key,
        [
          37, 31, 138, 40, 138, 219, 211, 151, //
          99, 22, 39, 219, 175, 159, 194, 207,
          17, 191, 2, 126, 78, 54, 204, 136,
          237, 81, 229, 35, 123, 126, 74, 152,
        ],
      );
    });

    test('same input + salt is deterministic across calls', () async {
      final salt = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];
      final a = await BackupCodec.deriveKey(keySource: 'my secret', salt: salt);
      final b = await BackupCodec.deriveKey(keySource: 'my secret', salt: salt);
      expect(a, b);
    });
  });

  group('header serialize / parse round-trip', () {
    test('preserves version, encMode and kdf fields', () {
      final salt = List<int>.generate(16, (i) => i);
      final map = BackupCodec.buildHeader(
        encMode: BackupCodec.encModeMagicWord,
        salt: salt,
      );
      expect(map['version'], 2);
      expect(map['encMode'], 'magicword');
      expect(map['kdf']['algo'], 'PBKDF2-HMAC-SHA256');
      expect(map['kdf']['iterations'], 100000);

      final parsed = BackupCodec.parseHeader(map);
      expect(parsed.version, 2);
      expect(parsed.encMode, 'magicword');
      expect(parsed.kdfAlgo, 'PBKDF2-HMAC-SHA256');
      expect(parsed.iterations, 100000);
      expect(parsed.salt, salt);
    });
  });

  group('new-format round-trip', () {
    test('encMode=uid encrypt -> decrypt', () async {
      final codec = BackupCodec(random: _SeqRandom());
      final zip = _makeZip({'hello': 'uid-world'});
      final bytes = await codec.encryptNew(
        zip,
        encMode: BackupCodec.encModeUid,
        keySource: 'test_uid_12345',
      );

      // Starts with "SBCB".
      expect(bytes.sublist(0, 4), BackupCodec.magic);
      final header = codec.readHeaderOrNull(bytes);
      expect(header!.encMode, 'uid');

      final out = await codec.decrypt(bytes, uid: 'test_uid_12345');
      expect(_readZip(out)['hello'], 'uid-world');
    });

    test('encMode=magicword encrypt -> decrypt with the word', () async {
      final codec = BackupCodec(random: _SeqRandom());
      final zip = _makeZip({'hello': 'magic-world'});
      final bytes = await codec.encryptNew(
        zip,
        encMode: BackupCodec.encModeMagicWord,
        keySource: 'correcthorse',
      );

      final header = codec.readHeaderOrNull(bytes);
      expect(header!.encMode, 'magicword');
      expect(header.isMagicWord, true);

      final out = await codec.decrypt(
        bytes,
        uid: 'test_uid_12345',
        magicWord: 'correcthorse',
      );
      expect(_readZip(out)['hello'], 'magic-world');
    });
  });

  group('legacy version-1 compatibility', () {
    test('IV(16)+CTR uid-as-key file decrypts via the legacy path', () async {
      const uid = 'legacy_uid_999';
      final zip = _makeZip({'hello': 'legacy-world'});

      // Hand-build a legacy file exactly like the original backup_service.
      final keyString = uid.padRight(32, '*').substring(0, 32);
      final key = encrypt.Key.fromUtf8(keyString);
      final iv = encrypt.IV.fromLength(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final encrypted = encrypter.encryptBytes(zip, iv: iv);
      final legacyBytes = iv.bytes + encrypted.bytes;

      // No "SBCB" magic -> routed to the legacy path.
      final codec = BackupCodec();
      expect(codec.readHeaderOrNull(legacyBytes), isNull);

      final out = await codec.decrypt(legacyBytes, uid: uid);
      expect(_readZip(out)['hello'], 'legacy-world');
    });
  });

  group('privacy rule: magicword never falls back to uid', () {
    test('wrong magic word throws WrongMagicWordFailure (no garbage)',
        () async {
      final codec = BackupCodec(random: _SeqRandom());
      final zip = _makeZip({'hello': 'secret'});
      final bytes = await codec.encryptNew(
        zip,
        encMode: BackupCodec.encModeMagicWord,
        keySource: 'therightword',
      );

      expect(
        () => codec.decrypt(bytes, uid: 'any_uid', magicWord: 'thewrongword'),
        throwsA(isA<WrongMagicWordFailure>()),
      );
    });

    test('missing magic word on a magicword file throws, never tries uid',
        () async {
      final codec = BackupCodec(random: _SeqRandom());
      final zip = _makeZip({'hello': 'secret'});
      final bytes = await codec.encryptNew(
        zip,
        encMode: BackupCodec.encModeMagicWord,
        keySource: 'therightword',
      );

      // Even if uid happened to equal the word, we don't try it: no word given.
      expect(
        () => codec.decrypt(bytes, uid: 'therightword'),
        throwsA(isA<WrongMagicWordFailure>()),
      );
    });
  });
}
