import 'package:email_validator/email_validator.dart';

/// Utility class for email-related operations
class EmailUtils {
  EmailUtils._();

  /// List of common free email domains
  static const freeEmailDomains = {
    // Google
    'gmail.com',
    'googlemail.com',

    // Microsoft
    'outlook.com',
    'hotmail.com',
    'live.com',
    'msn.com',

    // Yahoo
    'yahoo.com',
    'yahoo.co.uk',
    'yahoo.fr',
    'yahoo.de',
    'yahoo.it',
    'yahoo.es',
    'ymail.com',

    // Apple
    'icloud.com',
    'me.com',
    'mac.com',

    // Other popular free providers
    'aol.com',
    'protonmail.com',
    'proton.me',
    'mail.com',
    'gmx.com',
    'zoho.com',
    'tutanota.com',
    'fastmail.com',

    // Regional providers
    'qq.com',
    '163.com',
    '126.com',
    'sina.com',
    'sohu.com',
  };

  /// Validates if an email address is in correct format
  static bool isValidEmail(String email) {
    return EmailValidator.validate(email);
  }

  /// Extracts the domain from an email address
  /// Returns null if email is invalid
  static String? extractDomain(String email) {
    if (!isValidEmail(email)) return null;

    final parts = email.split('@');
    if (parts.length != 2) return null;

    return parts[1].toLowerCase();
  }

  /// Checks if an email is a business email (not a free email provider)
  /// Returns true if it's likely a business/corporate email
  static bool isBusinessEmail(String email) {
    final domain = extractDomain(email);
    if (domain == null) return false;

    // Check if domain is in free email list
    return !freeEmailDomains.contains(domain);
  }

  /// Gets the business email domain if it's a business email
  /// Returns null if it's a free email provider
  static String? getBusinessDomain(String email) {
    if (!isBusinessEmail(email)) return null;
    return extractDomain(email);
  }
}
