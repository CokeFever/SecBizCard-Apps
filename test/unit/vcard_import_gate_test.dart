import 'package:flutter_test/flutter_test.dart';
import 'package:secbizcard/features/contacts/presentation/screens/vcard_import_screen.dart';

/// Task 4: the "Import from Text" button is enabled only when the pasted text
/// structurally looks like a vCard. The button's `onPressed` is driven directly
/// by [looksLikeVCard]; this verifies the enable/disable gate logic. The real
/// parse/validation still runs in full on tap (not exercised here).
void main() {
  group('looksLikeVCard enable gate', () {
    test('empty / whitespace-only text is rejected', () {
      expect(looksLikeVCard(''), isFalse);
      expect(looksLikeVCard('   \n\t  '), isFalse);
    });

    test('arbitrary non-vCard text is rejected', () {
      expect(looksLikeVCard('hello world'), isFalse);
      expect(looksLikeVCard('just some pasted notes'), isFalse);
    });

    test('text missing END:VCARD is rejected', () {
      expect(looksLikeVCard('BEGIN:VCARD\nVERSION:2.1\nFN:John'), isFalse);
    });

    test('text missing BEGIN:VCARD is rejected', () {
      expect(looksLikeVCard('FN:John\nEND:VCARD'), isFalse);
    });

    test('a well-formed vCard is accepted', () {
      const vcard = 'BEGIN:VCARD\n'
          'VERSION:2.1\n'
          'N:Doe;John\n'
          'FN:John Doe\n'
          'TEL:+1234567890\n'
          'EMAIL:john@example.com\n'
          'END:VCARD';
      expect(looksLikeVCard(vcard), isTrue);
    });

    test('matching is case-insensitive', () {
      expect(
        looksLikeVCard('begin:vcard\nfn:john\nend:vcard'),
        isTrue,
      );
    });

    test('surrounding whitespace is tolerated', () {
      expect(
        looksLikeVCard('\n\n  BEGIN:VCARD\nFN:A\nEND:VCARD  \n'),
        isTrue,
      );
    });
  });
}
