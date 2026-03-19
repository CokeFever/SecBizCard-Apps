import 'package:uuid/uuid.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';
import 'dart:convert';
import 'dart:io';

class VCardService {
  static const _uuid = Uuid();

  /// Parses a vCard string and returns a list of UserProfiles.
  /// Supports vCard 2.1, 3.0, and 4.0 (best-effort).
  static List<UserProfile> parse(String content) {
    final contacts = <UserProfile>[];
    final vcardBlocks = _splitIntoVCardBlocks(content);

    for (final block in vcardBlocks) {
      final profile = _parseSingleVCard(block);
      if (profile != null) {
        contacts.add(profile);
      }
    }

    return contacts;
  }

  /// Generates a vCard 3.0 string for a given UserProfile.
  static String generate(UserProfile profile) {
    final sb = StringBuffer();
    sb.writeln('BEGIN:VCARD');
    sb.writeln('VERSION:3.0'); // Enforcing 3.0 as requested
    sb.writeln('FN:${profile.displayName}');
    sb.writeln('N:${_generateN(profile.displayName)}');

    if (profile.title?.isNotEmpty ?? false) {
      sb.writeln('TITLE:${profile.title}');
    }

    if (profile.company?.isNotEmpty ?? false) {
      if (profile.department?.isNotEmpty ?? false) {
        sb.writeln('ORG:${profile.company};${profile.department}');
      } else {
        sb.writeln('ORG:${profile.company}');
      }
    } else if (profile.department?.isNotEmpty ?? false) {
      sb.writeln('ORG:;${profile.department}');
    }

    if (profile.email?.isNotEmpty ?? false) {
      sb.writeln('EMAIL;TYPE=INTERNET:${profile.email}');
    }

    // Phone Priorities: Work, Mobile, Fax

    // Work Phone (mapped to 'phone')
    if (profile.phone?.isNotEmpty ?? false) {
      sb.writeln('TEL;TYPE=WORK,VOICE:${profile.phone}');
    }

    // Mobile Phone
    if (profile.mobile?.isNotEmpty ?? false) {
      sb.writeln('TEL;TYPE=CELL,VOICE:${profile.mobile}');
    }

    // Custom Fields for other phones
    profile.customFields.forEach((key, value) {
      if (key.contains('fax')) {
        sb.writeln('TEL;TYPE=FAX:$value');
      } else if (key.contains('home')) {
        sb.writeln('TEL;TYPE=HOME,VOICE:$value');
      }
    });

    if (profile.address?.isNotEmpty ?? false) {
      // Escape newlines for vCard
      final safeAddr = profile.address!
          .replaceAll('\n', '\\n')
          .replaceAll(',', '\\,');
      sb.writeln('ADR;TYPE=WORK:;;$safeAddr;;;;');
    }

    if (profile.website?.isNotEmpty ?? false) {
      sb.writeln('URL:${profile.website}');
    }

    // Photo Support
    try {
      String? imagePath = profile.flatImagePath;
      if (imagePath == null || imagePath.isEmpty) {
        imagePath = profile.originalImagePath;
      }

      if (imagePath != null && imagePath.isNotEmpty) {
        final file = File(imagePath);
        if (file.existsSync()) {
          final bytes = file.readAsBytesSync();
          final b64 = base64Encode(bytes);
          // vCard 3.0 standard for inline photo
          // Clean base64 strings often need to be folded, but modern readers usually handle long lines.
          // Standard says folding is recommended. Dart's base64Encode produces one long line.
          sb.writeln('PHOTO;ENCODING=b;TYPE=JPEG:$b64');
        }
      }
    } catch (e) {
      // Ignore photo errors during export to prevent failure
      print('Error exporting photo to vCard: $e');
    }

    sb.writeln('END:VCARD');
    return sb.toString();
  }

  static String _generateN(String fn) {
    // Simple heuristic to split FN into N (Family;Given)
    // For Western names: "John Doe" -> "Doe;John"
    // For Chinese names: "王小明" -> "王;小明" (Often FN is just set)
    // vCard 3.0 N is mandatory.
    final parts = fn.trim().split(' ');
    if (parts.length > 1) {
      final family = parts.last;
      final given = parts.sublist(0, parts.length - 1).join(' ');
      return '$family;$given;;;';
    }
    return '$fn;;;;';
  }

  static List<String> _splitIntoVCardBlocks(String content) {
    final blocks = <String>[];
    final lines = content.split(RegExp(r'\r?\n'));

    StringBuffer? currentBlock;
    for (final line in lines) {
      if (line.trim().startsWith('BEGIN:VCARD')) {
        currentBlock = StringBuffer();
      }
      currentBlock?.writeln(line);
      if (line.trim().startsWith('END:VCARD')) {
        if (currentBlock != null) {
          blocks.add(currentBlock.toString());
          currentBlock = null;
        }
      }
    }
    return blocks;
  }

  static UserProfile? _parseSingleVCard(String block) {
    final lines = block.split(RegExp(r'\r?\n'));
    // Unfold lines (vCard splitting) - simplistic approach: join lines starting with space
    final unfoldedLines = <String>[];
    for (var line in lines) {
      if (line.isEmpty) continue;
      if (line.startsWith(' ') || line.startsWith('\t')) {
        if (unfoldedLines.isNotEmpty) {
          unfoldedLines[unfoldedLines.length - 1] += line.trimLeft();
        }
      } else {
        unfoldedLines.add(line);
      }
    }

    String? fn;
    String? email;
    String? workPhone;
    String? mobilePhone;
    String? org; // company
    String? dept;
    String? title;
    String? adr;
    String? url;

    final customFields = <String, String>{};

    for (final line in unfoldedLines) {
      final parts = line.split(':');
      if (parts.length < 2) continue;

      final tagAndParams = parts[0].toUpperCase();
      final value = parts
          .sublist(1)
          .join(':')
          .trim(); // Join back in case value has colons (URL)

      if (tagAndParams.startsWith('FN')) {
        fn = value;
      } else if (tagAndParams.startsWith('N') &&
          !tagAndParams.startsWith('NOTE') &&
          fn == null) {
        // Fallback if FN missing
        final nParts = value.split(';');
        if (nParts.isNotEmpty) {
          final family = nParts[0];
          final given = nParts.length > 1 ? nParts[1] : '';
          fn = '$given $family'.trim();
        }
      } else if (tagAndParams.startsWith('EMAIL')) {
        email ??= value;
      } else if (tagAndParams.startsWith('TEL')) {
        // Parse Types
        // vCard 2.1: TEL;WORK;VOICE:
        // vCard 3.0: TEL;TYPE=WORK,VOICE:
        final upperParams = tagAndParams.toUpperCase();

        var isWork = upperParams.contains('WORK');
        var isCell =
            upperParams.contains('CELL') || upperParams.contains('MOBILE');
        var isFax = upperParams.contains('FAX');
        var isHome = upperParams.contains('HOME');

        // If "TYPE=" syntax used
        if (upperParams.contains('TYPE=')) {
          // robust check? or simple contains is enough?
          // simple contains is usually enough for these standard types
        } else {
          // v 2.1 check (already covered by contains)
        }

        // Assignment Priority:
        if (isFax) {
          customFields['phone_fax'] = value;
        } else if (isCell) {
          mobilePhone = value;
        } else if (isWork) {
          workPhone = value;
        } else if (isHome) {
          customFields['phone_home'] = value;
        } else {
          // Default fallback
          workPhone ??= value;
          mobilePhone ??= value;
        }
      } else if (tagAndParams.startsWith('ORG')) {
        final orgParts = value.split(';');
        org = orgParts.firstOrNull?.trim();
        if (orgParts.length > 1) dept = orgParts[1].trim();
      } else if (tagAndParams.startsWith('TITLE')) {
        title = value;
      } else if (tagAndParams.startsWith('ADR')) {
        // ADR;TYPE=WORK:;;123 Main St;City;State;Zip;Country
        final adrParts = value.split(';');
        // Basic join of non-empty parts
        adr = adrParts.where((s) => s.isNotEmpty).join(', ').trim();
      } else if (tagAndParams.startsWith('URL')) {
        url = value;
      }
    }

    if (fn == null &&
        email == null &&
        workPhone == null &&
        mobilePhone == null) {
      return null;
    }

    return UserProfile(
      uid: _uuid.v4(),
      email: email ?? '',
      displayName: fn ?? email ?? 'Unknown',
      title: title,
      company: org,
      department: dept,
      phone: workPhone, // Maps to 'phone' (Work)
      mobile: mobilePhone, // Maps to 'mobile' (Cell)
      address: adr,
      website: url,
      customFields: customFields,
      createdAt: DateTime.now(),
      source: 'vcf',
    );
  }
}
