import 'package:flutter_test/flutter_test.dart';
import 'package:secbizcard/features/contacts/data/services/vcard_service.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';

/// FEAT-002: the single `department` field threads OCR -> model -> vCard ->
/// backup. These lock the three serialization-sensitive behaviors design.md
/// Testability calls out: vCard ORG second component, missing-key -> null, and
/// a toJson/fromJson round-trip.
void main() {
  UserProfile base({String? company, String? department}) => UserProfile(
        uid: 'test-uid',
        displayName: 'Jane Doe',
        company: company,
        department: department,
        createdAt: DateTime(2026, 1, 1),
      );

  group('vCard department (ORG second component)', () {
    test('generate emits ORG:Company;Department', () {
      final vcard = VCardService.generate(
        base(company: 'Acme Corp', department: 'R&D Division'),
        includePhoto: false,
      );
      expect(vcard, contains('ORG:Acme Corp;R&D Division'));
    });

    test('parse of ORG:A;B yields department == "B"', () {
      const vcard = 'BEGIN:VCARD\n'
          'VERSION:3.0\n'
          'FN:Jane Doe\n'
          'ORG:Acme Corp;R&D Division\n'
          'END:VCARD';
      final contacts = VCardService.parse(vcard);
      expect(contacts, hasLength(1));
      expect(contacts.first.company, 'Acme Corp');
      expect(contacts.first.department, 'R&D Division');
    });
  });

  group('UserProfile JSON', () {
    test('fromJson of a map WITHOUT department yields department == null', () {
      final json = <String, dynamic>{
        'uid': 'test-uid',
        'displayName': 'Jane Doe',
        'company': 'Acme Corp',
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
      };
      final profile = UserProfile.fromJson(json);
      expect(profile.department, isNull);
    });

    test('fromJson(toJson()) round-trip preserves a set department', () {
      final original = base(company: 'Acme Corp', department: 'R&D Division');
      final restored = UserProfile.fromJson(original.toJson());
      expect(restored.department, 'R&D Division');
    });
  });
}
