import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:secbizcard/features/auth/data/auth_repository.dart';
import 'package:secbizcard/features/profile/data/profile_repository.dart';
import 'package:secbizcard/features/verification/data/email_verification_repository.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  /// Optional custom email to verify (e.g., Work Email)
  /// If null, uses the Firebase Auth email
  final String? customEmail;

  const EmailVerificationScreen({super.key, this.customEmail});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  bool _isLoading = false;
  bool _emailSent = false;
  String? _errorMessage;
  String? _successMessage;

  Future<void> _sendVerificationEmail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final repository = ref.read(emailVerificationRepositoryProvider);
    final user = ref.read(authRepositoryProvider).getCurrentUser();

    // Check if we are verifying a custom email (update flow) or current email
    final isCustomEmail =
        widget.customEmail != null && widget.customEmail != user?.email;

    final result = isCustomEmail
        ? await repository.verifyBeforeUpdateEmail(widget.customEmail!)
        : await repository.sendVerificationEmail();

    result.fold(
      (failure) {
        setState(() {
          _errorMessage = failure.message;
          _isLoading = false;
        });
      },
      (_) {
        setState(() {
          _emailSent = true;
          _successMessage = isCustomEmail
              ? 'Verification email sent to ${widget.customEmail}! Click the link to update your login email.'
              : 'Verification email sent! Please check your inbox.';
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _checkVerificationStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final repository = ref.read(emailVerificationRepositoryProvider);
    final authRepo = ref.read(authRepositoryProvider);

    // For custom email, we check if the auth email has been updated
    if (widget.customEmail != null) {
      final user = authRepo.getCurrentUser();
      await user?.reload(); // Refresh user data
      final updatedUser = authRepo.getCurrentUser(); // Get refreshed user

      if (updatedUser?.email == widget.customEmail) {
        // Success: Email updated and verified
        // Update profile email verified status if needed (Auth handles it mostly)
        // But we might want to ensure Firestore matches
        await ref
            .read(profileRepositoryProvider)
            .markEmailAsVerified(updatedUser!.uid);

        if (mounted) {
          Navigator.of(context).pop(true);
        }
        return;
      }
    }

    // Standard flow
    final result = await repository.checkEmailVerified();

    result.fold(
      (failure) {
        setState(() {
          _errorMessage = failure.message;
          _isLoading = false;
        });
      },
      (isVerified) async {
        if (isVerified) {
          // Sync to Profile in Firestore
          final user = ref.read(authRepositoryProvider).getCurrentUser();
          if (user != null) {
            await ref
                .read(profileRepositoryProvider)
                .markEmailAsVerified(user.uid);
          }

          if (mounted) {
            Navigator.of(context).pop(true); // Return true to indicate success
          }
        } else {
          setState(() {
            _errorMessage =
                'Email not verified yet. Please check your inbox and click the verification link.';
            _isLoading = false;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.read(emailVerificationRepositoryProvider);
    // Use custom email if provided, otherwise use Firebase Auth email
    final userEmail = widget.customEmail ?? repository.getUserEmail();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Verify Email',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              _emailSent ? Icons.mark_email_read : Icons.email_outlined,
              size: 80,
              color: _emailSent ? Colors.green : Colors.blue,
            ),
            const SizedBox(height: 24),
            Text(
              _emailSent ? 'Check your email' : 'Verify your email',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (userEmail != null)
              Text(
                userEmail,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 16),
            Text(
              _emailSent
                  ? 'We sent a verification link to your email. Click the link to verify your email address.'
                  : 'We\'ll send you a verification link to confirm your email address.',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (_successMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: TextStyle(color: Colors.green.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            if (!_emailSent)
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _sendVerificationEmail,
                icon: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(
                  'Send Verification Email',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            else ...[
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _checkVerificationStatus,
                icon: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(
                  'I\'ve Verified',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _sendVerificationEmail,
                icon: const Icon(Icons.refresh),
                label: Text(
                  'Resend Email',
                  style: GoogleFonts.inter(fontSize: 14),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Tips',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Check your spam folder if you don\'t see the email\n'
                    '• The verification link expires after 1 hour\n'
                    '• You can resend the email if needed',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
