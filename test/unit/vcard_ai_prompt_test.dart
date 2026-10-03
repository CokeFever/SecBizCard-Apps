import 'package:flutter_test/flutter_test.dart';
import 'package:secbizcard/features/contacts/presentation/screens/vcard_import_screen.dart';

/// Task 3: the "Copy AI Prompt" button copies [kVCardAiPrompt] to the
/// clipboard. The prompt is intentionally hardcoded English (fed to an LLM, not
/// shown as app UI) and must guide the AI to handle MULTIPLE business cards and
/// emit one vCard 2.1 entry per card. These assertions stay loose enough to
/// survive minor wording edits while locking in the multi-card intent.
void main() {
  group('kVCardAiPrompt', () {
    test('conveys that multiple cards (1 to 6) may be present', () {
      expect(kVCardAiPrompt, contains('1 to 6'));
      expect(kVCardAiPrompt.toLowerCase(), contains('cards'));
    });

    test('asks for vCard 2.1 output', () {
      expect(kVCardAiPrompt, contains('vCard 2.1'));
    });

    test('asks the AI to output the vCard text to copy', () {
      expect(kVCardAiPrompt.toLowerCase(), contains('vcard text'));
      expect(kVCardAiPrompt.toLowerCase(), contains('copy'));
    });

    test('mentions one entry per card / multiple VCARD blocks', () {
      expect(kVCardAiPrompt, contains('BEGIN:VCARD'));
      expect(kVCardAiPrompt, contains('END:VCARD'));
    });
  });
}
