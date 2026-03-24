import 'dart:convert';
import 'dart:io';

void main() {
  print('--- Dart Secret Injector ---');

  injectSecret('GOOGLE_SERVICE_INFO_PLIST', 'ios/Runner/GoogleService-Info.plist');
  injectSecret('GOOGLE_SERVICES_JSON', 'android/app/google-services.json');
  injectSecret('FIREBASE_OPTIONS_DART', 'lib/firebase_options.dart');
  
  // Also handle the SSH key for private repo
  injectSecret('OCR_DEPLOY_KEY', '.ssh_id_ed25519', isBinary: true);
}

void injectSecret(String envName, String filePath, {bool isBinary = false}) {
  final Map<String, String> env = Platform.environment;
  final String? rawBase64 = env[envName];

  if (rawBase64 == null || rawBase64.isEmpty) {
    print('Warning: Environment variable $envName is missing or empty.');
    return;
  }

  try {
    // 1. Clean whitespace
    String cleanBase64 = rawBase64.trim().replaceAll(RegExp(r'\s+'), '');
    
    // 2. Normalize URL-safe Base64 to Standard Base64
    // '-' -> '+', '_' -> '/'
    cleanBase64 = cleanBase64.replaceAll('-', '+').replaceAll('_', '/');
    
    // 3. Proper padding
    while (cleanBase64.length % 4 != 0) {
      cleanBase64 += '=';
    }

    // 4. Decode
    final List<int> decodedBytes = base64.decode(cleanBase64);
    
    if (decodedBytes.isEmpty) {
      print('Error: Decoded data for $envName is empty.');
      return;
    }

    // 5. Write to file
    final File file = File(filePath);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(decodedBytes);

    print('Successfully injected $envName into $filePath (${decodedBytes.length} bytes).');
    
    // 6. Health check (peek first 20 bytes)
    final String peek = decodedBytes.take(20).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    print('  Peek (HEX): $peek');

  } catch (e) {
    print('Error injecting $envName: $e');
  }
}
