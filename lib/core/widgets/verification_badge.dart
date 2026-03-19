import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum VerificationType { phone, email, business }

/// A badge widget to display verification status
class VerificationBadge extends StatelessWidget {
  final VerificationType type;
  final bool isVerified;
  final DateTime? verifiedAt;
  final bool showLabel;

  const VerificationBadge({
    super.key,
    required this.type,
    required this.isVerified,
    this.verifiedAt,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVerified) return const SizedBox.shrink();

    final color = _getColor();
    final icon = _getIcon();
    final label = _getLabel();

    return Tooltip(
      message: _getTooltipMessage(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            if (showLabel) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getColor() {
    switch (type) {
      case VerificationType.phone:
        return Colors.green;
      case VerificationType.email:
        return Colors.green;
      case VerificationType.business:
        return Colors.purple;
    }
  }

  IconData _getIcon() {
    switch (type) {
      case VerificationType.phone:
        return Icons.phone_android;
      case VerificationType.email:
        return Icons.email;
      case VerificationType.business:
        return Icons.business;
    }
  }

  String _getLabel() {
    switch (type) {
      case VerificationType.phone:
        return 'Verified';
      case VerificationType.email:
        return 'Verified';
      case VerificationType.business:
        return 'Business';
    }
  }

  String _getTooltipMessage() {
    final typeStr = type == VerificationType.phone
        ? 'Phone'
        : type == VerificationType.email
        ? 'Email'
        : 'Business Email';

    if (verifiedAt != null) {
      final date = _formatDate(verifiedAt!);
      return '$typeStr verified on $date';
    }

    return '$typeStr verified';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// Compact verification badge for inline use
class CompactVerificationBadge extends StatelessWidget {
  final VerificationType type;
  final bool isVerified;

  const CompactVerificationBadge({
    super.key,
    required this.type,
    required this.isVerified,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVerified) return const SizedBox.shrink();

    final color = type == VerificationType.phone
        ? Colors.green
        : type == VerificationType.email
        ? Colors.green
        : Colors.purple;

    return Tooltip(
      message: '${type.name} verified',
      child: Icon(Icons.verified, size: 16, color: color),
    );
  }
}
