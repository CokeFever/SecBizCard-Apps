import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:secbizcard/generated/l10n/app_localizations.dart';

class DialogUtils {
  /// Shows a confirmation dialog when the user attempts to leave a screen with unsaved changes.
  /// Returns [true] if the user wants to discard changes and leave, [false] otherwise.
  static Future<bool?> showUnsavedChangesDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.unsavedChangesTitle,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(l10n.unsavedChangesBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.unsavedChangesStay),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.unsavedChangesDiscard),
          ),
        ],
      ),
    );
  }
}
