import 'package:flutter/material.dart';

class FieldFormatter {
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
