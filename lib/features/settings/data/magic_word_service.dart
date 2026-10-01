import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

import 'package:secbizcard/core/errors/failure.dart';

part 'magic_word_service.g.dart';

/// Stores the user's optional backup "magic word" securely on-device.
///
/// The magic word is the key source for encrypting the Google Drive backup
/// (see docs/web_portal_and_e2e_encryption_plan.md). It mirrors the BYOK key
/// handling in [OcrSettingsService]:
///  - stored in the platform secure enclave via flutter_secure_storage
///    (iOS Keychain / Android Keystore), same accessibility option;
///  - never written to logs, plain preferences, or synced storage;
///  - cleared on sign-out alongside the BYOK key and the contacts DB.
///
/// Lifecycle: survives app updates, disappears on uninstall / device change /
/// sign-out. Once set, backup & restore use it automatically — the user is only
/// prompted when the local value is absent (new device / reinstall / logout).
///
/// PRIVACY: once a backup is written in `magicword` mode it can ONLY be
/// decrypted with the magic word; the uid key is never a fallback. Forgetting
/// the word means the magicword backup can never be restored.
class MagicWordService {
  MagicWordService(this._secure);

  final FlutterSecureStorage _secure;

  static const String kMagicWord = 'backup_magic_word';

  /// Minimum / maximum length (inclusive) enforced after normalization.
  static const int minLength = 8;
  static const int maxLength = 16;

  /// Normalizes a magic word the same way on read AND write so that two inputs
  /// that "look the same" but differ in whitespace or Unicode composition still
  /// derive the same key: trim surrounding whitespace, then Unicode NFC.
  static String normalize(String value) => unorm.nfc(value.trim());

  /// Whether [value] is a valid magic word AFTER normalization. Only the length
  /// (8-16) is enforced; symbols, spaces and mixed case are all allowed and no
  /// composition is forced (per the plan's rules).
  static bool isValid(String value) {
    final normalized = normalize(value);
    return normalized.length >= minLength && normalized.length <= maxLength;
  }

  /// Returns the stored magic word (already normalized), or null if none is set.
  Future<String?> getMagicWord() async {
    final value = await _secure.read(key: kMagicWord);
    if (value == null) return null;
    final normalized = normalize(value);
    return normalized.isEmpty ? null : normalized;
  }

  /// Stores [value] (normalized). Throws [MagicWordValidationFailure] if the
  /// normalized value is not 8-16 characters.
  Future<void> setMagicWord(String value) async {
    final normalized = normalize(value);
    if (normalized.length < minLength || normalized.length > maxLength) {
      throw const MagicWordValidationFailure();
    }
    await _secure.write(key: kMagicWord, value: normalized);
  }

  Future<void> clearMagicWord() => _secure.delete(key: kMagicWord);

  Future<bool> hasMagicWord() async => (await getMagicWord()) != null;
}

/// Shared secure-storage options for magic word + BYOK (keep in sync with
/// [OcrSettingsService]). Exposed so sign-out can clear both with identical
/// options from AuthRepository without importing Flutter widgets.
FlutterSecureStorage buildSecureStorage() => const FlutterSecureStorage(
      aOptions: AndroidOptions(),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    );

@Riverpod(keepAlive: true)
MagicWordService magicWordService(Ref ref) {
  return MagicWordService(buildSecureStorage());
}

/// Whether the user has set a backup magic word (drives UI + logout warning).
@riverpod
Future<bool> hasMagicWord(Ref ref) async {
  return ref.watch(magicWordServiceProvider).hasMagicWord();
}
