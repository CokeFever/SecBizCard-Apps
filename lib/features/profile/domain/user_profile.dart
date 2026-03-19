import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_profile.freezed.dart';
part 'user_profile.g.dart';

@freezed
class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String uid,
    String? email,
    required String displayName,
    String? photoUrl,
    String? avatarDriveFileId,
    String? title,
    String? company,
    String? department,
    String? phone,
    String? address,
    @JsonKey(fromJson: _createdAtFromJson) required DateTime createdAt,
    @Default({}) Map<String, dynamic> contextsJson,
    @Default({})
    Map<String, String>
    customFields, // For dynamic fields like Website, LinkedIn, etc.
    // Verification fields
    @Default(false) bool phoneVerified,
    @Default(false) bool emailVerified,
    String? businessEmailDomain,
    DateTime? phoneVerifiedAt,
    DateTime? emailVerifiedAt,
    @Default(false) bool isOnboardingComplete,
    String? fcmToken,
    // New fields for OCR/Import
    String? originalImagePath,
    String? flatImagePath,
    @Default('handshake') String source, // 'handshake' | 'vcf' | 'ocr'
    String? mobile,
    String? website,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);
}

DateTime _createdAtFromJson(dynamic timestamp) {
  if (timestamp == null) return DateTime.now();
  if (timestamp is String) return DateTime.parse(timestamp);
  if (timestamp is int) return DateTime.fromMillisecondsSinceEpoch(timestamp);
  return DateTime.now();
}
