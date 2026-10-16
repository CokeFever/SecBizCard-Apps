// Unit tests for the LocaleResolver fallback ladder (FEAT-002, design
// Decisions 3-4). Pure, no widget tree.
//
// Covers the full ladder matrix and enforces the Decision-3 equality invariant:
// every value LocaleResolver.resolve returns must be a member of the generated
// AppLocalizations.supportedLocales (else MaterialApp silently falls back to
// supportedLocales.first == Locale('en')).

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:secbizcard/core/i18n/locale_resolver.dart';
import 'package:secbizcard/generated/l10n/app_localizations.dart';

void main() {
  const zhHant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
  const zhHans = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');
  const en = Locale('en');
  const ja = Locale('ja');
  const ko = Locale('ko');

  // Full input matrix: each entry is (description, device-locale list, expected).
  final matrix = <({String desc, List<Locale>? input, Locale expected})>[
    // Chinese — explicit script subtag (rule 2a, step 1).
    (desc: 'zh-Hant', input: [zhHant], expected: zhHant),
    (desc: 'zh-Hans', input: [zhHans], expected: zhHans),
    (
      desc: 'zh-Hant-HK (script subtag beats region)',
      input: [const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'HK')],
      expected: zhHant,
    ),
    (
      desc: 'zh-Hant-TW (script+region) -> Hant',
      input: [const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW')],
      expected: zhHant,
    ),
    (
      desc: 'zh-Hans-SG (script subtag beats region)',
      input: [const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans', countryCode: 'SG')],
      expected: zhHans,
    ),
    // Chinese — region inference (step 2).
    (desc: 'zh-TW -> Hant', input: [const Locale('zh', 'TW')], expected: zhHant),
    (desc: 'zh-HK -> Hant', input: [const Locale('zh', 'HK')], expected: zhHant),
    (desc: 'zh-MO -> Hant', input: [const Locale('zh', 'MO')], expected: zhHant),
    (desc: 'zh-CN -> Hans', input: [const Locale('zh', 'CN')], expected: zhHans),
    (desc: 'zh-SG -> Hans', input: [const Locale('zh', 'SG')], expected: zhHans),
    // Chinese — rule 2b: no clear script -> Traditional.
    (desc: 'bare zh -> Hant (2b)', input: [const Locale('zh')], expected: zhHant),
    (desc: 'zh-MY -> Hant (2b, MY not in Hans set)', input: [const Locale('zh', 'MY')], expected: zhHant),
    (desc: 'zh-XX unknown region -> Hant (2b)', input: [const Locale('zh', 'XX')], expected: zhHant),
    // Non-Chinese supported languages (rule 2c).
    (desc: 'ja', input: [ja], expected: ja),
    (desc: 'ko', input: [ko], expected: ko),
    (desc: 'en', input: [en], expected: en),
    (desc: 'en-US', input: [const Locale('en', 'US')], expected: en),
    // Unsupported / catch-all (rule 2d).
    (desc: 'fr -> en', input: [const Locale('fr')], expected: en),
    (desc: 'null device list -> en', input: null, expected: en),
    (desc: 'empty device list -> en', input: <Locale>[], expected: en),
    // Ordered multi-locale lists: first mappable wins.
    (desc: '[fr-FR, ja-JP] -> ja', input: [const Locale('fr', 'FR'), const Locale('ja', 'JP')], expected: ja),
    (desc: '[fr, de, zh-CN] -> Hans', input: [const Locale('fr'), const Locale('de'), const Locale('zh', 'CN')], expected: zhHans),
    (desc: '[ja, zh-TW] -> ja (primary wins)', input: [ja, const Locale('zh', 'TW')], expected: ja),
  ];

  group('LocaleResolver.resolve ladder', () {
    for (final c in matrix) {
      test('${c.desc} resolves correctly', () {
        expect(
          LocaleResolver.resolve(c.input, AppLocalizations.supportedLocales),
          c.expected,
        );
      });
    }
  });

  group('supportedLocales containment invariant (Decision 3)', () {
    for (final c in matrix) {
      test('${c.desc} returns a declared supported locale', () {
        final r = LocaleResolver.resolve(c.input, AppLocalizations.supportedLocales);
        expect(
          AppLocalizations.supportedLocales.contains(r),
          isTrue,
          reason: 'resolve returned $r which is not in supportedLocales',
        );
      });
    }
  });

  test('generated supportedLocales carries exact script-coded zh entries', () {
    expect(AppLocalizations.supportedLocales.contains(zhHant), isTrue);
    expect(AppLocalizations.supportedLocales.contains(zhHans), isTrue);
    // The resolver's constants must be the Locale.fromSubtags form so == holds.
    expect(LocaleResolver.zhHant, zhHant);
    expect(LocaleResolver.zhHans, zhHans);
    expect(LocaleResolver.zhHant.scriptCode, 'Hant');
    expect(LocaleResolver.zhHans.scriptCode, 'Hans');
  });
}
