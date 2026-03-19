import 'package:secbizcard/features/profile/domain/user_profile.dart';
import 'package:secbizcard/features/profile/domain/card_context.dart';

extension UserProfileFilter on UserProfile {
  Map<String, dynamic> filterForContext(ContextType type) {
    // Base identity fields present in all contexts
    final Map<String, dynamic> filtered = {
      'uid': uid,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'contextsJson': contextsJson, // Keep contexts syncing for now
      'createdAt': createdAt.toIso8601String(),
      'isOnboardingComplete': isOnboardingComplete,
      // Always include verification status, but maybe not the sensitive data
      'phoneVerified': phoneVerified,
      'emailVerified': emailVerified,
    };

    if (type == ContextType.lite) {
      // Lite: Only base identity
      return filtered;
    }

    if (type == ContextType.social) {
      // Social: Add fields appropriate for social context
      // Assuming customFields might have social links.
      // If we had specific fields for "personal phone" vs "work phone", we'd distinguish here.
      // For now, let's include custom fields and maybe phone if it's generic.
      filtered['customFields'] = customFields;
      filtered['phone'] = phone;
      // Exclude email, title, company in social context?
      // Often people want to share everything in social too, but let's be restrictive as per "Social" naming.
      // Or maybe Social includes everything EXCEPT strict business details?
      // Let's assume Social includes basic contact info + social links.
    }

    if (type == ContextType.business) {
      // Business: Full professional profile
      filtered['email'] = email;
      filtered['title'] = title;
      filtered['company'] = company;
      filtered['phone'] = phone; // Usually work phone or primary phone
      filtered['businessEmailDomain'] = businessEmailDomain;
      filtered['customFields'] =
          customFields; // LinkedIn, Website etc. often business related

      // If we had specific business address, etc.
    }

    return filtered;
  }
}
