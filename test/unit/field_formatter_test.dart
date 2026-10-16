// Unit coverage for FieldFormatter.localizedLabel (FEAT-003, design Decision 1).
//
// Uses the generated English AppLocalizations so the assertions read against the
// real ARB strings. The three resolution branches are exercised: reserved
// exact-match keys, {category}_{label}[_N] composition, and the English
// formatLabel fallback for unknown/user-typed keys.

import 'package:flutter_test/flutter_test.dart';
import 'package:secbizcard/core/utils/field_formatter.dart';
import 'package:secbizcard/generated/l10n/app_localizations.dart';
import 'package:secbizcard/generated/l10n/app_localizations_en.dart';

void main() {
  final AppLocalizations l10n = AppLocalizationsEn();

  group('FieldFormatter.localizedLabel reserved keys', () {
    test("'fax' reuses reviewFieldFax", () {
      expect(FieldFormatter.localizedLabel(l10n, 'fax'), l10n.reviewFieldFax);
    });

    test("'taxId' reuses reviewFieldTaxId", () {
      expect(
        FieldFormatter.localizedLabel(l10n, 'taxId'),
        l10n.reviewFieldTaxId,
      );
    });

    test("'Nickname' (capital N) maps to customFieldNickname", () {
      expect(
        FieldFormatter.localizedLabel(l10n, 'Nickname'),
        l10n.customFieldNickname,
      );
    });

    test('alt*/city/postalCode map to their customField getters', () {
      expect(
        FieldFormatter.localizedLabel(l10n, 'altName'),
        l10n.customFieldAltName,
      );
      expect(
        FieldFormatter.localizedLabel(l10n, 'altAddress'),
        l10n.customFieldAltAddress,
      );
      expect(FieldFormatter.localizedLabel(l10n, 'city'), l10n.customFieldCity);
      expect(
        FieldFormatter.localizedLabel(l10n, 'postalCode'),
        l10n.customFieldPostalCode,
      );
    });
  });

  group('FieldFormatter.localizedLabel {category}_{label} composition', () {
    test('phone_work composes label + category (English order)', () {
      expect(
        FieldFormatter.localizedLabel(l10n, 'phone_work'),
        l10n.customFieldLabelComposed(
          l10n.customFieldLabelWork,
          l10n.customFieldCategoryPhone,
        ),
      );
    });

    test('social_linkedin composes using the closed vocabulary', () {
      expect(
        FieldFormatter.localizedLabel(l10n, 'social_linkedin'),
        l10n.customFieldLabelComposed(
          l10n.customFieldLabelLinkedin,
          l10n.customFieldCategorySocial,
        ),
      );
    });

    test('a numeric suffix is appended language-neutrally', () {
      final base = l10n.customFieldLabelComposed(
        l10n.customFieldLabelWork,
        l10n.customFieldCategoryPhone,
      );
      expect(
        FieldFormatter.localizedLabel(l10n, 'phone_work_2'),
        '$base 2',
      );
    });
  });

  group('FieldFormatter.localizedLabel English fallback', () {
    test('an unknown composed category falls back to formatLabel', () {
      // 'widget' is not in the closed category vocabulary.
      expect(
        FieldFormatter.localizedLabel(l10n, 'widget_special'),
        FieldFormatter.formatLabel('widget_special'),
      );
    });

    test('a bare user-typed key falls back to formatLabel', () {
      expect(
        FieldFormatter.localizedLabel(l10n, 'someCustomThing'),
        FieldFormatter.formatLabel('someCustomThing'),
      );
    });
  });
}
