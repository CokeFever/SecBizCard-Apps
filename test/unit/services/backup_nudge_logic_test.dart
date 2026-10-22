// Unit tests for the no-magic-word backup nudge predicate (FEAT-002, sub-task
// B). The predicate decides when the soft nudge fires: only when the cloud file
// is NOT already magic-word protected (D11 owns that case) AND this device has
// no magic word.

import 'package:flutter_test/flutter_test.dart';
import 'package:secbizcard/features/settings/presentation/screens/backup_screen.dart';

void main() {
  group('shouldNudgeNoMagicWord', () {
    test('cloud protected + no local word -> false (D11 owns it)', () {
      expect(
        shouldNudgeNoMagicWord(
          cloudMagicWordProtected: true,
          hasLocalWord: false,
        ),
        isFalse,
      );
    });

    test('cloud not protected + no local word -> true (nudge fires)', () {
      expect(
        shouldNudgeNoMagicWord(
          cloudMagicWordProtected: false,
          hasLocalWord: false,
        ),
        isTrue,
      );
    });

    test('cloud protected + has local word -> false', () {
      expect(
        shouldNudgeNoMagicWord(
          cloudMagicWordProtected: true,
          hasLocalWord: true,
        ),
        isFalse,
      );
    });

    test('cloud not protected + has local word -> false', () {
      expect(
        shouldNudgeNoMagicWord(
          cloudMagicWordProtected: false,
          hasLocalWord: true,
        ),
        isFalse,
      );
    });
  });
}
