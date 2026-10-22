// ARB parity, placeholder-integrity, and residual-Traditional-glyph guard for
// the five-locale ARB set (FEAT-001, design Decisions 1-3).
//
// This test is the authoritative gate for three invariants that gen-l10n alone
// does not fully enforce:
//
//   (a) PARITY — every non-template locale carries all 569 non-@ template keys
//       from app_en.arb. Counting is done by JSON parse of non-@ keys, NEVER a
//       line grep (grep -c '":' returns a higher number for the zh files and
//       for en because en carries all the @-metadata).
//
//   (b) PLACEHOLDER INTEGRITY — for every key present in a locale, the set of
//       ICU {placeholder} tokens matches app_en.arb's token set for that key,
//       so a translation can never drop/rename/add a substitution slot.
//
//   (c) RESIDUAL-TRADITIONAL AUDIT — a programmatic Traditional-only-glyph scan
//       over all 530 values of app_zh_Hans.arb. The scan flags any value that
//       contains a glyph whose Simplified form differs; the Simplified file
//       must flag ZERO keys. The glyph set deliberately EXCLUDES script-neutral
//       glyphs 藏 and 辨 (identical in both scripts), so the 7-key 辨识 set is
//       not flagged here — it is a separate QA-vocabulary item owned by
//       qa-localization, not a Traditional straggler.
//
// Paths are relative to the package root, which is flutter_test's working
// directory.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _l10nDir = 'lib/l10n';
const _templateLocale = 'en';

/// Non-template locales that must have full key parity with app_en.arb.
const _nonTemplateLocales = <String>[
  'ja',
  'ko',
  'zh', // base (Traditional)
  'zh_Hans',
  'zh_Hant',
];

/// Traditional-only Han glyphs — glyphs whose Simplified form differs. Seed set
/// from design Decision 2. CRITICAL: this set EXCLUDES script-neutral glyphs
/// (notably 藏 and 辨) that are identical in both scripts, so they never
/// false-positive the Simplified file.
const _traditionalOnlyGlyphs = <String>{
  '專', '業', '檔', '個', '編', '輯', '設', '資', '網', '數', '鑰', '這', '門',
  '簡', '帳', '連', '線', '軟', '體', '質', '裝', '備', '錄', '們', '將', '執',
  '觀', '點', '擊', '傳', '輸', '處', '國', '際', '關', '閉', '開', '啟', '選',
  '單', '確', '認', '說', '讀', '寫', '顯', '視', '覺', '語', '訊', '號', '碼',
  '頁', '應', '該', '產', '發', '經', '導', '歸', '還', '屬', '據', '證', '驗',
  '簽', '畫',
};

/// Parse an ARB file to a JSON map. Throws (rather than calling `expect`) so it
/// is safe to call from `main`'s body before any `test()` block runs.
Map<String, dynamic> _loadArb(String locale) {
  final file = File('$_l10nDir/app_$locale.arb');
  if (!file.existsSync()) {
    throw StateError('ARB file missing: ${file.path}');
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

/// The translatable (non-@) keys of an ARB map.
Set<String> _nonAtKeys(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();

/// Extract the set of ICU placeholder tokens ({name}) from a string value.
final _placeholderRe = RegExp(r'\{([^{}]+)\}');
Set<String> _placeholders(String value) =>
    _placeholderRe.allMatches(value).map((m) => m.group(1)!).toSet();

void main() {
  final template = _loadArb(_templateLocale);
  final templateKeys = _nonAtKeys(template);

  test('template app_en.arb has the expected 569 non-@ keys', () {
    expect(templateKeys.length, 569);
  });

  group('(a) key parity with app_en.arb', () {
    for (final locale in _nonTemplateLocales) {
      test('app_$locale.arb contains all 569 template keys', () {
        final arb = _loadArb(locale);
        final keys = _nonAtKeys(arb);
        final missing = templateKeys.difference(keys);
        expect(
          missing,
          isEmpty,
          reason: 'app_$locale.arb is missing keys: $missing',
        );
        expect(
          keys.length,
          templateKeys.length,
          reason:
              'app_$locale.arb has ${keys.length} non-@ keys, '
              'expected ${templateKeys.length}',
        );
      });
    }
  });

  group('(b) placeholder integrity vs app_en.arb', () {
    for (final locale in _nonTemplateLocales) {
      test('app_$locale.arb placeholder tokens match the template', () {
        final arb = _loadArb(locale);
        final mismatches = <String>[];
        for (final key in templateKeys) {
          final templateValue = template[key];
          final localeValue = arb[key];
          if (templateValue is! String || localeValue is! String) continue;
          final expectedTokens = _placeholders(templateValue);
          final actualTokens = _placeholders(localeValue);
          if (!_setEquals(expectedTokens, actualTokens)) {
            mismatches.add(
              '$key: expected $expectedTokens, got $actualTokens',
            );
          }
        }
        expect(
          mismatches,
          isEmpty,
          reason:
              'app_$locale.arb placeholder mismatches:\n'
              '${mismatches.join('\n')}',
        );
      });
    }
  });

  group('(c) residual-Traditional glyph scan of app_zh_Hans.arb', () {
    test('no Simplified value contains a Traditional-only glyph', () {
      final hans = _loadArb('zh_Hans');
      final flagged = <String, String>{};
      for (final key in _nonAtKeys(hans)) {
        final value = hans[key];
        if (value is! String) continue;
        for (final rune in value.runes) {
          final ch = String.fromCharCode(rune);
          if (_traditionalOnlyGlyphs.contains(ch)) {
            flagged[key] = value;
            break;
          }
        }
      }
      expect(
        flagged,
        isEmpty,
        reason:
            'app_zh_Hans.arb has residual Traditional glyphs in:\n'
            '${flagged.entries.map((e) => '${e.key}: ${e.value}').join('\n')}',
      );
    });
  });
}

bool _setEquals(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);
