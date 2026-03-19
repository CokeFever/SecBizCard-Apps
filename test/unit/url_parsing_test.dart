import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Handshake URL Parsing', () {
    test('Parses standard handshake URL', () {
      final uri = Uri.parse('https://ixo.app/handshake/session123');
      final segments = uri.pathSegments;

      expect(segments.length, 2);
      expect(segments[0], 'handshake');
      expect(segments[1], 'session123');

      // Logic check
      bool matched = false;
      if (segments.length == 2 && segments[0] == 'handshake') {
        matched = true;
      }
      expect(matched, true);
    });

    test('Parses offline username URL', () {
      final uri = Uri.parse('https://ixo.app/u/john_doe');
      final segments = uri.pathSegments;

      expect(segments.length, 2);
      expect(segments[0], 'u');
      expect(segments[1], 'john_doe');

      // Logic check
      bool matched = false;
      if (segments.length == 2 && segments[0] == 'u') {
        matched = true;
      }
      expect(matched, true);
    });

    test('Parses online username handshake URL', () {
      final uri = Uri.parse('https://ixo.app/u/john_doe/session123');
      final segments = uri.pathSegments;

      expect(segments.length, 3);
      expect(segments[0], 'u');
      expect(segments[1], 'john_doe');
      expect(segments[2], 'session123');

      // Logic check
      bool matched = false;
      String? sessionId;
      if (segments.length == 3 && segments[0] == 'u') {
        matched = true;
        sessionId = segments[2];
      }
      expect(matched, true);
      expect(sessionId, 'session123');
    });
  });
}
