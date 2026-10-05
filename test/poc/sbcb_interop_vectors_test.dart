// POC interop harness (SBCB v2 crypto) — Dart side.
//
// This is a scratch harness for the web-editor crypto POC. It is NOT part of
// the shipping app; it only reads/writes vector JSON files consumed by the
// JS/Web Crypto POC in the SecBizCard repo
// (website/poc/crypto-interop/). See that folder's POC_FINDINGS.md.
//
// It drives three jobs via the POC_JOB env var:
//
//   POC_JOB=emit  POC_OUT=<path>
//       Encrypt known plaintexts with backup_codec.dart using FIXED salt+nonce
//       (so output is reproducible) in both uid and magicword modes, plus dump
//       the PBKDF2 key hex for a fixed password+salt. Writes a JSON vector file
//       the JS side decrypts (interop direction b) and compares keys against
//       (direction d).
//
//   POC_JOB=verify  POC_IN=<path>
//       Read a JS-PRODUCED vector file and DECRYPT each case with
//       backup_codec.dart, asserting the recovered plaintext matches. This is
//       the critical direction (c): the Flutter app opening a browser-written
//       backup.
//
// Run from the app repo, e.g.:
//   POC_JOB=emit POC_OUT=/abs/path/dart_vectors.json fvm flutter test test/poc/sbcb_interop_vectors_test.dart
//   POC_JOB=verify POC_IN=/abs/path/js_vectors.json  fvm flutter test test/poc/sbcb_interop_vectors_test.dart

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

import 'package:secbizcard/core/services/backup_codec.dart';

/// Mirrors MagicWordService.normalize: trim surrounding whitespace, then NFC.
/// BackupCodec.decrypt does NOT normalize — the app normalizes before calling
/// it — so this POC harness applies the same normalization the app would.
String _normalizeMagicWord(String v) => unorm.nfc(v.trim());

/// Deterministic RNG that emits a caller-supplied byte stream (salt then
/// nonce), so Dart produces a byte-exact file the JS side can reproduce with
/// the same fixed salt+nonce.
class _FixedRandom implements Random {
  _FixedRandom(this._stream);
  final List<int> _stream;
  int _i = 0;
  @override
  int nextInt(int max) {
    final v = _stream[_i++ % _stream.length];
    return v % max;
  }

  @override
  bool nextBool() => nextInt(2) == 1;
  @override
  double nextDouble() => nextInt(1 << 20) / (1 << 20);
}

String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

List<int> _unhex(String s) {
  final out = <int>[];
  for (var i = 0; i < s.length; i += 2) {
    out.add(int.parse(s.substring(i, i + 2), radix: 16));
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final job = Platform.environment['POC_JOB'];

  // Fixed, documented inputs shared with the JS side.
  const uid = 'firebase_uid_ABC123';
  const magicWord = 'correct horse '; // intentional surrounding/inner space:
  // after normalize -> 'correct horse' (trim only strips the ends; NFC no-op).
  final fixedSaltUid = List<int>.generate(16, (i) => i); // 00..0f
  final fixedNonceUid = List<int>.generate(12, (i) => 0x10 + i); // 10..1b
  final fixedSaltMw = List<int>.generate(16, (i) => 0x20 + i); // 20..2f
  final fixedNonceMw = List<int>.generate(12, (i) => 0x30 + i); // 30..3b

  final uidPlaintext = utf8.encode(jsonEncode({'hello': 'uid-world', 'n': 1}));
  final mwPlaintext =
      utf8.encode(jsonEncode({'hello': 'magic-world', 'items': [1, 2, 3]}));

  test('POC: emit Dart vectors / verify JS vectors / key anchor', () async {
    if (job == 'emit') {
      final outPath = Platform.environment['POC_OUT']!;

      // uid-mode file with fixed salt+nonce.
      final uidCodec =
          BackupCodec(random: _FixedRandom([...fixedSaltUid, ...fixedNonceUid]));
      final uidFile = await uidCodec.encryptNew(
        uidPlaintext,
        encMode: BackupCodec.encModeUid,
        keySource: uid,
      );

      // magicword-mode file. The app always derives the key from the NORMALIZED
      // word; replicate that here by passing the normalized form.
      final normalizedWord = magicWord.trim(); // NFC no-op for ASCII
      final mwCodec =
          BackupCodec(random: _FixedRandom([...fixedSaltMw, ...fixedNonceMw]));
      final mwFile = await mwCodec.encryptNew(
        mwPlaintext,
        encMode: BackupCodec.encModeMagicWord,
        keySource: normalizedWord,
      );

      // Key anchor (direction d): PBKDF2("password", 16x0x00).
      final anchorSalt = List<int>.filled(16, 0);
      final anchorKey =
          await BackupCodec.deriveKey(keySource: 'password', salt: anchorSalt);

      final vectors = {
        'note': 'Produced by backup_codec.dart (Dart source of truth).',
        'uid': uid,
        'magicWordRaw': magicWord,
        'magicWordNormalized': normalizedWord,
        'cases': [
          {
            'mode': 'uid',
            'keySource': uid,
            'saltHex': _hex(fixedSaltUid),
            'nonceHex': _hex(fixedNonceUid),
            'plaintextHex': _hex(uidPlaintext),
            'sbcbBase64': base64Encode(uidFile),
          },
          {
            'mode': 'magicword',
            'keySource': normalizedWord,
            'saltHex': _hex(fixedSaltMw),
            'nonceHex': _hex(fixedNonceMw),
            'plaintextHex': _hex(mwPlaintext),
            'sbcbBase64': base64Encode(mwFile),
          },
        ],
        'keyAnchor': {
          'password': 'password',
          'saltHex': _hex(anchorSalt),
          'keyHex': _hex(anchorKey),
        },
      };

      File(outPath)
          .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(vectors));
      // Sanity: the salt bytes we fed actually landed in the header.
      final h = uidCodec.readHeaderOrNull(uidFile)!;
      expect(h.salt, fixedSaltUid);
      expect(h.encMode, 'uid');
      // ignore: avoid_print
      print('POC emit wrote vectors to $outPath');
      return;
    }

    if (job == 'verify') {
      final inPath = Platform.environment['POC_IN']!;
      final data = jsonDecode(File(inPath).readAsStringSync())
          as Map<String, dynamic>;
      final codec = BackupCodec();
      final jsUid = data['uid'] as String;
      final jsMagicWord = data['magicWordRaw'] as String;

      final cases = (data['cases'] as List).cast<Map<String, dynamic>>();
      expect(cases, isNotEmpty);
      for (final c in cases) {
        final sbcb = base64Decode(c['sbcbBase64'] as String);
        final expectedPlain =
            Uint8List.fromList(_unhex(c['plaintextHex'] as String));
        final out = await codec.decrypt(
          sbcb,
          uid: jsUid,
          // The app normalizes the user's word (MagicWordService.normalize)
          // before calling decrypt; do the same here so a browser-written
          // magicword file opens with the raw word the user types.
          magicWord: _normalizeMagicWord(jsMagicWord),
        );
        expect(
          Uint8List.fromList(out),
          expectedPlain,
          reason: 'Dart failed to recover JS-written ${c['mode']} plaintext',
        );
      }

      // Direction (d) cross-check: recompute the key anchor and compare to the
      // hex the JS side recorded.
      final anchor = data['keyAnchor'] as Map<String, dynamic>;
      final key = await BackupCodec.deriveKey(
        keySource: anchor['password'] as String,
        salt: _unhex(anchor['saltHex'] as String),
      );
      expect(_hex(key), anchor['keyHex'],
          reason: 'PBKDF2 key hex mismatch between JS and Dart');
      // ignore: avoid_print
      print('POC verify: Dart decrypted all JS vectors; key anchor matches.');
      return;
    }

    fail('Set POC_JOB=emit or POC_JOB=verify (see file header).');
  });
}
