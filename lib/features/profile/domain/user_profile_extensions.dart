import 'package:secbizcard/features/profile/domain/user_profile.dart';
import 'package:secbizcard/features/profile/domain/card_context.dart';

extension UserProfileFilter on UserProfile {
  Map<String, dynamic> filterForContext(ContextType type) {
    // 1. Get the context settings for this type
    CardContext context;
    if (contextsJson.containsKey(type.name)) {
      try {
        context = CardContext.fromJson(contextsJson[type.name] as Map<String, dynamic>);
      } catch (e) {
        context = CardContext.createDefaults()[type]!;
      }
    } else {
      context = CardContext.createDefaults()[type]!;
    }

    // 2. Build the filtered map
    final Map<String, dynamic> filtered = {
      'uid': uid,
      'createdAt': createdAt.toIso8601String(),
      'isOnboardingComplete': isOnboardingComplete,
      'phoneVerified': phoneVerified,
      'emailVerified': emailVerified,
    };

    if (context.showName) filtered['displayName'] = displayName;
    if (context.showEmail) filtered['email'] = email;
    if (context.showPhone) filtered['phone'] = phone;
    if (context.showTitle) filtered['title'] = title;
    if (context.showCompany) filtered['company'] = company;
    if (context.showAvatar) {
      filtered['photoUrl'] = photoUrl;
      filtered['avatarDriveFileId'] = avatarDriveFileId;
    }
    
    // Business Card Images
    if (context.showCardFront) filtered['cardFrontUrl'] = cardFrontDriveFileId;
    if (context.showCardBack) filtered['cardBackUrl'] = cardBackDriveFileId;

    // Custom Fields
    if (customFields.isNotEmpty) {
      final Map<String, String> filteredCustomFields = {};
      customFields.forEach((key, value) {
        // Check if this specific custom field should be shown
        if (context.showCustomFields[key] ?? true) {
          filteredCustomFields[key] = value;
        }
      });
      if (filteredCustomFields.isNotEmpty) {
        filtered['customFields'] = filteredCustomFields;
      }
    }

    return filtered;
  }
}
