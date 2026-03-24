import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DialogUtils {
  /// Shows a confirmation dialog when the user attempts to leave a screen with unsaved changes.
  /// Returns [true] if the user wants to discard changes and leave, [false] otherwise.
  static Future<bool?> showUnsavedChangesDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Unsaved Changes',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'You have unsaved changes. Are you sure you want to discard them and leave?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }
}
