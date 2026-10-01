import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

import 'package:secbizcard/core/errors/failure.dart';

/// Owns the backup file byte layout — the app↔web binary contract defined in
/// docs/web_portal_and_e2e_encryption_plan.md ("備份檔格式(定案...)"). PURE
/// Dart (no Flutter imports) so the exact same bytes can be reproduced by a
/// future JS Web Crypto implementation.
///
/// New (version 2) layout:
/// ```
/// [4B  ASCII "SBCB"]
/// [2B  header length, big-endian uint16]
/// [N   JSON header, UTF-8]
/// [12B AES-GCM nonce/IV]
/// [M   ciphertext + 16B GCM tag]
/// ```
/// JSON header:
/// ```json
/// { "version": 2, "encMode": "uid" | "magicword",
///   "kdf": { "algo": "PBKDF2-HMAC-SHA256", "iterations": 100000,
///            "salt": "<base64, 16B>" } }
/// ```
///
/// Legacy (version 1) files have NO "SBCB" magic: `IV(16) + AES-CTR ciphertext`
/// keyed by the uid padded/truncated to 32 bytes. Those decrypt via the
/// `encrypt` package default (SIC/CTR) path and are supported forever.
///
/// Crypto parameters are fixed and standard: PBKDF2-HMAC-SHA256, 100000
/// iterations, 16-byte random salt → 32-byte AES-256 key; AES-256-GCM with a
/// 12-byte nonce and 16-byte tag.
class BackupCodec {
  /// 4-byte magic marking the new version-2 format.
  static const List<int> magic = [0x53, 0x42, 0x43, 0x42]; // "SBCB"

  static const int version = 2;
  static const String encModeUid = 'uid';
  static const String encModeMagicWord = 'magicword';

  static const String kdfAlgo = 'PBKDF2-HMAC-SHA256';
  static const int kdfIterations = 100000;
  static const int saltLength = 16;
  static const int keyLength = 32; // AES-256
  static const int gcmNonceLength = 12;
  static const int gcmTagLength = 16;

  final Random _random;

  /// [random] is overridable for deterministic tests. Production uses a
  /// cryptographically secure RNG.
  BackupCodec({Random? random}) : _random = random ?? Random.secure();

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  /// Builds the JSON header map for a new-format file.
  static Map<String, dynamic> buildHeader({
    required String encMode,
    required List<int> salt,
  }) {
    return {
      'version': version,
      'encMode': encMode,
      'kdf': {
        'algo': kdfAlgo,
        'iterations': kdfIterations,
        'salt': base64Encode(salt),
      },
    };
  }

  /// Parses and validates a header map produced by [buildHeader].
  static BackupHeader parseHeader(Map<String, dynamic> json) {
    final encMode = json['encMode'] as String?;
    if (encMode != encModeUid && encMode != encModeMagicWord) {
      throw const BackupFormatFailure('Unknown encMode in backup header');
    }
    final kdf = json['kdf'] as Map<String, dynamic>?;
    if (kdf == null) {
      throw const BackupFormatFailure('Missing kdf in backup header');
    }
    final saltB64 = kdf['salt'] as String?;
    if (saltB64 == null) {
      throw const BackupFormatFailure('Missing kdf.salt in backup header');
    }
    return BackupHeader(
      version: (json['version'] as num?)?.toInt() ?? version,
      encMode: encMode!,
      kdfAlgo: kdf['algo'] as String? ?? kdfAlgo,
      iterations: (kdf['iterations'] as num?)?.toInt() ?? kdfIterations,
      salt: base64Decode(saltB64),
    );
  }

  // ---------------------------------------------------------------------------
  // Key derivation (PBKDF2-HMAC-SHA256)
  // ---------------------------------------------------------------------------

  /// Derives the 32-byte AES-256 key from [keySource] (uid or magic word) and
  /// [salt] using PBKDF2-HMAC-SHA256, 100000 iterations. Deterministic and
  /// standard so a Web Crypto `deriveBits` call matches bit-for-bit.
  static Future<List<int>> deriveKey({
    required String keySource,
    required List<int> salt,
  }) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: kdfIterations,
      bits: keyLength * 8,
    );
    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(keySource)),
      nonce: salt,
    );
    return secretKey.extractBytes();
  }

  // ---------------------------------------------------------------------------
  // Encrypt (always new format)
  // ---------------------------------------------------------------------------

  /// Encrypts [plaintextZip] into a new-format ("SBCB") file.
  ///
  /// [encMode] is `uid` or `magicword`; [keySource] is the matching secret
  /// (the uid, or the normalized magic word). Generates a random 16-byte salt
  /// and 12-byte GCM nonce.
  Future<List<int>> encryptNew(
    List<int> plaintextZip, {
    required String encMode,
    required String keySource,
  }) async {
    final salt = _randomBytes(saltLength);
    final key = await deriveKey(keySource: keySource, salt: salt);

    final nonce = _randomBytes(gcmNonceLength);
    final aesGcm = AesGcm.with256bits();
    final secretBox = await aesGcm.encrypt(
      plaintextZip,
      secretKey: SecretKey(key),
      nonce: nonce,
    );

    final headerJson = utf8.encode(jsonEncode(buildHeader(
      encMode: encMode,
      salt: salt,
    )));

    if (headerJson.length > 0xFFFF) {
      throw const BackupFormatFailure('Backup header too large');
    }

    final out = BytesBuilder();
    out.add(magic);
    final lenBytes = ByteData(2)..setUint16(0, headerJson.length, Endian.big);
    out.add(lenBytes.buffer.asUint8List());
    out.add(headerJson);
    out.add(secretBox.nonce); // 12B IV
    out.add(secretBox.cipherText); // ciphertext
    out.add(secretBox.mac.bytes); // 16B GCM tag
    return out.toBytes();
  }

  // ---------------------------------------------------------------------------
  // Decrypt (routes by format / header)
  // ---------------------------------------------------------------------------

  /// Decrypts [bytes] back to the plaintext ZIP.
  ///
  /// Routing:
  ///  - No "SBCB" magic → LEGACY version-1: `IV(16) + AES-CTR`, key = uid
  ///    padded/truncated to 32 bytes (the original backup_service logic).
  ///  - Header `encMode=uid` → PBKDF2(uid, salt) + AES-GCM.
  ///  - Header `encMode=magicword` → REQUIRES [magicWord]; PBKDF2(word, salt) +
  ///    AES-GCM. NEVER falls back to uid. A GCM tag failure surfaces as
  ///    [WrongMagicWordFailure]; a missing word surfaces as
  ///    [WrongMagicWordFailure] too (no silent uid attempt).
  Future<List<int>> decrypt(
    List<int> bytes, {
    required String uid,
    String? magicWord,
  }) async {
    if (!_hasMagic(bytes)) {
      return _decryptLegacy(bytes, uid);
    }

    final header = _readHeader(bytes);
    final bodyOffset = magic.length + 2 + header.headerLength;
    final body = bytes.sublist(bodyOffset);

    if (header.header.encMode == encModeMagicWord) {
      if (magicWord == null || magicWord.isEmpty) {
        // Privacy rule: magicword files are never retried with uid. Without a
        // word there is nothing valid to try.
        throw const WrongMagicWordFailure('Magic word required for this backup');
      }
      return _decryptGcm(body, keySource: magicWord, salt: header.header.salt,
          magicWordMode: true);
    }

    // encMode == uid (new format): PBKDF2(uid) + GCM.
    return _decryptGcm(body, keySource: uid, salt: header.header.salt,
        magicWordMode: false);
  }

  /// Reads the encMode of a file WITHOUT decrypting. Returns null for a legacy
  /// (no-magic) file. Lets callers decide whether a magic word is needed.
  BackupHeader? readHeaderOrNull(List<int> bytes) {
    if (!_hasMagic(bytes)) return null;
    return _readHeader(bytes).header;
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  bool _hasMagic(List<int> bytes) {
    if (bytes.length < magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[i] != magic[i]) return false;
    }
    return true;
  }

  _ParsedHeader _readHeader(List<int> bytes) {
    if (bytes.length < magic.length + 2) {
      throw const BackupFormatFailure('Truncated backup header');
    }
    final headerLen = ByteData.sublistView(
      Uint8List.fromList(bytes.sublist(magic.length, magic.length + 2)),
    ).getUint16(0, Endian.big);
    final headerStart = magic.length + 2;
    final headerEnd = headerStart + headerLen;
    if (bytes.length < headerEnd) {
      throw const BackupFormatFailure('Truncated backup header');
    }
    final headerJson = utf8.decode(bytes.sublist(headerStart, headerEnd));
    final map = jsonDecode(headerJson) as Map<String, dynamic>;
    return _ParsedHeader(parseHeader(map), headerLen);
  }

  Future<List<int>> _decryptGcm(
    List<int> body, {
    required String keySource,
    required List<int> salt,
    required bool magicWordMode,
  }) async {
    if (body.length < gcmNonceLength + gcmTagLength) {
      throw const BackupFormatFailure('Truncated backup body');
    }
    final nonce = body.sublist(0, gcmNonceLength);
    final cipherText = body.sublist(gcmNonceLength, body.length - gcmTagLength);
    final macBytes = body.sublist(body.length - gcmTagLength);

    final key = await deriveKey(keySource: keySource, salt: salt);
    final aesGcm = AesGcm.with256bits();
    try {
      return await aesGcm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
        secretKey: SecretKey(key),
      );
    } on SecretBoxAuthenticationError {
      // Wrong key / tampered file. In magicword mode this is the wrong word;
      // either way we NEVER retry with uid.
      if (magicWordMode) {
        throw const WrongMagicWordFailure();
      }
      throw const BackupFormatFailure('Backup authentication failed');
    }
  }

  /// Legacy version-1 path: `IV(16) + AES-CTR ciphertext`, key = uid padded to
  /// 32 bytes. Byte-identical to the original backup_service decrypt.
  Future<List<int>> _decryptLegacy(List<int> bytes, String uid) async {
    if (bytes.length <= 16) {
      throw const BackupFormatFailure('Truncated legacy backup');
    }
    final ivBytes = bytes.sublist(0, 16);
    final contentBytes = bytes.sublist(16);

    final keyString = uid.padRight(32, '*').substring(0, 32);
    final key = encrypt.Key.fromUtf8(keyString);
    final iv = encrypt.IV(Uint8List.fromList(ivBytes));
    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    return encrypter.decryptBytes(
      encrypt.Encrypted(Uint8List.fromList(contentBytes)),
      iv: iv,
    );
  }

  List<int> _randomBytes(int n) =>
      List<int>.generate(n, (_) => _random.nextInt(256));
}

/// Parsed, validated backup header fields.
class BackupHeader {
  final int version;
  final String encMode;
  final String kdfAlgo;
  final int iterations;
  final List<int> salt;

  const BackupHeader({
    required this.version,
    required this.encMode,
    required this.kdfAlgo,
    required this.iterations,
    required this.salt,
  });

  bool get isMagicWord => encMode == BackupCodec.encModeMagicWord;
}

class _ParsedHeader {
  final BackupHeader header;
  final int headerLength;
  const _ParsedHeader(this.header, this.headerLength);
}
