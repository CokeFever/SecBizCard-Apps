import 'dart:ui';

/// Pure locale-resolution ladder for the five supported locales
/// (zh-Hant, zh-Hans, ja, ko, en).
///
/// Wired as `MaterialApp.router`'s `localeListResolutionCallback`. It walks the
/// device's ordered preference list and returns one of the exact script-coded
/// [Locale] constants below, which compare `==` to the generated
/// `AppLocalizations.supportedLocales` entries so `lookupAppLocalizations`
/// resolves to the correct subclass.
///
/// Ladder (design Decision 4):
///  - 2a: explicit zh script subtag (Hant/Hans) wins.
///  - 2b: Chinese without a clear script → Traditional (zh-Hant).
///  - 2c: ja / ko / en map to themselves.
///  - 2d: nothing in the device list maps → English catch-all.
class LocaleResolver {
  LocaleResolver._();

  static const Locale zhHant =
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
  static const Locale zhHans =
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');
  static const Locale en = Locale('en');
  static const Locale ja = Locale('ja');
  static const Locale ko = Locale('ko');

  /// Resolve the device preference list to a single supported [Locale].
  ///
  /// Total function — never throws. A null/empty list, an unknown language, or
  /// a malformed locale all deterministically fall through to [en] (rule 2d).
  /// The [supported] argument is accepted to match the
  /// `localeListResolutionCallback` signature; resolution is driven by the
  /// hard-coded ladder, whose return values are themselves members of
  /// `supportedLocales`.
  static Locale resolve(List<Locale>? deviceLocales, Iterable<Locale> supported) {
    for (final loc in deviceLocales ?? const <Locale>[]) {
      final mapped = _mapOne(loc);
      if (mapped != null) return mapped;
    }
    // rule 2d catch-all: nothing in the device list mapped → English.
    return en;
  }

  static Locale? _mapOne(Locale loc) {
    switch (loc.languageCode.toLowerCase()) {
      case 'zh':
        final script = _inferChineseScript(loc);
        if (script == 'Hant') return zhHant; // 2a
        if (script == 'Hans') return zhHans; // 2a
        return zhHant; // 2b — Chinese w/o clear script → Traditional
      case 'ja':
        return ja; // 2c
      case 'ko':
        return ko; // 2c
      case 'en':
        return en; // 2c
      default:
        return null; // defer to next device locale
    }
  }

  static String? _inferChineseScript(Locale loc) {
    // Step 1 — explicit script subtag always wins.
    final s = loc.scriptCode;
    if (s == 'Hant') return 'Hant';
    if (s == 'Hans') return 'Hans';
    // Step 2 — region inference, only when no script subtag is present.
    final c = (loc.countryCode ?? '').toUpperCase();
    if (c == 'TW' || c == 'HK' || c == 'MO') return 'Hant';
    if (c == 'CN' || c == 'SG') return 'Hans';
    // Step 3 — bare 'zh', or any other region (incl. MY) with no script → null;
    // caller applies rule 2b → Traditional.
    return null;
  }
}
