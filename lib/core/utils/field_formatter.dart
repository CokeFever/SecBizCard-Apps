import 'package:flutter/material.dart';
import 'package:secbizcard/generated/l10n/app_localizations.dart';

class FieldFormatter {
  /// Localized renderer for a customFields key.
  ///
  /// Resolution order (deterministic, no I/O):
  /// 1. Reserved exact-match table (bare keys the app writes directly). `fax`
  ///    and `taxId` REUSE the existing review keys (no dedicated customField
  ///    key); the alt*/city/postalCode/Nickname keys map to [customField*].
  /// 2. `{category}_{label}[_N]` composition against the closed category/label
  ///    vocabulary (kept in lockstep with the web `field-grouping.ts`), resolved
  ///    through explicit switches (a missing case is a compile error) and
  ///    composed via the locale-aware [AppLocalizations.customFieldLabelComposed]
  ///    template. A trailing numeric suffix is appended language-neutrally.
  /// 3. Fall back to the English [formatLabel] for unknown/user-typed keys.
  static String localizedLabel(AppLocalizations l10n, String key) {
    // (1) Reserved exact-match table.
    switch (key) {
      case 'fax':
        return l10n.reviewFieldFax;
      case 'taxId':
        return l10n.reviewFieldTaxId;
      case 'Nickname':
        return l10n.customFieldNickname;
      case 'altName':
        return l10n.customFieldAltName;
      case 'altTitle':
        return l10n.customFieldAltTitle;
      case 'altCompany':
        return l10n.customFieldAltCompany;
      case 'altPhone':
        return l10n.customFieldAltPhone;
      case 'altAddress':
        return l10n.customFieldAltAddress;
      case 'city':
        return l10n.customFieldCity;
      case 'postalCode':
        return l10n.customFieldPostalCode;
    }

    // (2) {category}_{label}[_N] composition.
    final match = RegExp(r'^([a-zA-Z]+)_([a-zA-Z]+)(?:_(\d+))?$').firstMatch(key);
    if (match != null) {
      final category = _localizedCategory(l10n, match.group(1)!);
      final label = _localizedLabelComponent(l10n, match.group(2)!);
      if (category != null && label != null) {
        final composed = l10n.customFieldLabelComposed(label, category);
        final suffix = match.group(3);
        return suffix != null ? '$composed $suffix' : composed;
      }
    }

    // (3) English fallback for unknown/user-typed keys.
    return formatLabel(key);
  }

  /// Localized display for an Add-Field category dropdown value (the English
  /// machine value such as `Phone`/`Email`). Falls back to [value] verbatim for
  /// anything outside the closed vocabulary.
  static String addFieldCategoryLabel(AppLocalizations l10n, String value) {
    return _localizedCategory(l10n, value) ?? value;
  }

  /// Localized display for an Add-Field label dropdown value (the English
  /// machine value such as `Work`/`LinkedIn`). Falls back to [value] verbatim
  /// for anything outside the closed vocabulary.
  static String addFieldLabel(AppLocalizations l10n, String value) {
    return _localizedLabelComponent(l10n, value) ?? value;
  }

  /// Maps a lowercase category token to its localized string, or null if the
  /// token is outside the closed vocabulary (so the caller falls back).
  static String? _localizedCategory(AppLocalizations l10n, String category) {
    switch (category.toLowerCase()) {
      case 'phone':
        return l10n.customFieldCategoryPhone;
      case 'email':
        return l10n.customFieldCategoryEmail;
      case 'address':
        return l10n.customFieldCategoryAddress;
      case 'website':
        return l10n.customFieldCategoryWebsite;
      case 'social':
        return l10n.customFieldCategorySocial;
      case 'date':
        return l10n.customFieldCategoryDate;
      case 'note':
        return l10n.customFieldCategoryNote;
    }
    return null;
  }

  /// Maps a lowercase label token to its localized string, or null if the token
  /// is outside the closed vocabulary (so the caller falls back).
  static String? _localizedLabelComponent(AppLocalizations l10n, String label) {
    switch (label.toLowerCase()) {
      case 'work':
        return l10n.customFieldLabelWork;
      case 'home':
        return l10n.customFieldLabelHome;
      case 'mobile':
        return l10n.customFieldLabelMobile;
      case 'fax':
        return l10n.customFieldLabelFax;
      case 'main':
        return l10n.customFieldLabelMain;
      case 'other':
        return l10n.customFieldLabelOther;
      case 'personal':
        return l10n.customFieldLabelPersonal;
      case 'company':
        return l10n.customFieldLabelCompany;
      case 'blog':
        return l10n.customFieldLabelBlog;
      case 'portfolio':
        return l10n.customFieldLabelPortfolio;
      case 'linkedin':
        return l10n.customFieldLabelLinkedin;
      case 'twitter':
        return l10n.customFieldLabelTwitter;
      case 'facebook':
        return l10n.customFieldLabelFacebook;
      case 'instagram':
        return l10n.customFieldLabelInstagram;
      case 'github':
        return l10n.customFieldLabelGithub;
      case 'birthday':
        return l10n.customFieldLabelBirthday;
      case 'anniversary':
        return l10n.customFieldLabelAnniversary;
      case 'general':
        return l10n.customFieldLabelGeneral;
    }
    return null;
  }

  static String formatLabel(String key) {
    // Convert key (phone_work_2) to Label (Work Phone 2)
    final parts = key.split('_');
    if (parts.length < 2) {
      // Handle simple keys or capitalized keys
      return key[0].toUpperCase() + key.substring(1).replaceAll('_', ' ');
    }

    String category = parts[0];
    String label = parts[1];
    String suffix = parts.length > 2 ? ' ${parts[2]}' : '';

    // Capitalize
    category = category[0].toUpperCase() + category.substring(1);
    label = label[0].toUpperCase() + label.substring(1);

    // Swap order for English reading: Work Phone, not Phone Work
    return '$label $category$suffix';
  }

  static IconData getIcon(String key) {
    final lower = key.toLowerCase();
    if (lower.contains('website') ||
        lower.contains('url') ||
        lower.contains('link')) {
      return Icons.language_outlined;
    }
    if (lower.contains('linkedin')) {
      return Icons.work_outline;
    }
    if (lower.contains('twitter') || lower.contains('social') || lower.contains(' x ')) {
      return Icons.people_outline;
    }
    if (lower.contains('address')) {
      return Icons.location_on_outlined;
    }
    if (lower.contains('birthday') || lower.contains('date')) {
      return Icons.cake_outlined;
    }
    if (lower.contains('note')) {
      return Icons.note_outlined;
    }
    if (lower.contains('phone') ||
        lower.contains('mobile') ||
        lower.contains('fax')) {
      return Icons.phone_outlined;
    }
    if (lower.contains('email')) {
      return Icons.email_outlined;
    }
    if (lower.contains('company') || lower.contains('business')) {
      return Icons.business_outlined;
    }
    if (lower.contains('title') || lower.contains('job')) {
      return Icons.work_outline;
    }
    return Icons.info_outline;
  }
}
