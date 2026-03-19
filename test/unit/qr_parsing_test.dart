import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Strict QR Code URL Parsing Logic', () {
    // Logic from QrScannerScreen.dart:
    // final uri = Uri.tryParse(code);
    // final pathSegments = uri.pathSegments;
    // if (pathSegments.length != 1) { error }

    // Case 1: Valid Strict Format (https://ixo.app/{hash})
    const validUrl = 'https://ixo.app/session_123';
    final uri1 = Uri.parse(validUrl);
    expect(uri1.pathSegments.length, 1);
    expect(uri1.pathSegments[0], 'session_123');
    // Result: Valid

    // Case 2: Legacy Standard Format (Should Fail)
    const legacyStandard =
        'https://ixo-app-secbizcard.web.app/handshake/session_123';
    final uri2 = Uri.parse(legacyStandard);
    expect(uri2.pathSegments.length, 2);
    // Result: Invalid (Length != 1)

    // Case 3: Legacy Profile Format (Should Fail)
    const legacyProfile = 'https://ixo.app/u/username';
    final uri3 = Uri.parse(legacyProfile);
    expect(uri3.pathSegments.length, 2);
    // Result: Invalid (Length != 1)

    // Case 4: Raw ID (Should Pass if Uri.parse accepts it as path)
    const rawId = 'session_123';
    final uri4 = Uri.tryParse(rawId);
    expect(uri4?.pathSegments.length, 1);
    // Result: Valid (treated as relative path with 1 segment)
  });
}
