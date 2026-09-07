import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ocr_settings_service.g.dart';

/// Stores the user's own Cloud Vision API key securely on-device.
///
/// Security:
///  - The BYO API key is stored in the platform secure enclave via
///    flutter_secure_storage (iOS Keychain / Android Keystore). It is never
///    written to logs, plain preferences, or synced storage, and never leaves
///    the device — it's used to call Cloud Vision directly.
///
/// We intentionally do NOT track BYOK usage: when a user brings their own key,
/// recognition goes straight to Google (not our backend), so any local count
/// would be unreliable and misleading. Usage/spend is managed by the user in
/// the Google Cloud Console.
class OcrSettingsService {
  OcrSettingsService(this._secure);

  final FlutterSecureStorage _secure;

  static const _kApiKey = 'ocr_cloud_vision_api_key';

  /// Shared-key free scans per user per month (mirrors the backend cap). Shown
  /// in the "using shared quota" description.
  static const int sharedPerUserMonthly = 5;

  Future<String?> getApiKey() async {
    final key = await _secure.read(key: _kApiKey);
    if (key == null) return null;
    final trimmed = key.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> setApiKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      await _secure.delete(key: _kApiKey);
    } else {
      await _secure.write(key: _kApiKey, value: trimmed);
    }
  }

  Future<void> clearApiKey() => _secure.delete(key: _kApiKey);

  Future<bool> hasApiKey() async => (await getApiKey()) != null;
}

@Riverpod(keepAlive: true)
OcrSettingsService ocrSettingsService(Ref ref) {
  return OcrSettingsService(
    const FlutterSecureStorage(
      aOptions: AndroidOptions(),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    ),
  );
}

/// Whether the user has configured their own Cloud Vision key (drives UI).
@riverpod
Future<bool> hasOwnVisionKey(Ref ref) async {
  return ref.watch(ocrSettingsServiceProvider).hasApiKey();
}
