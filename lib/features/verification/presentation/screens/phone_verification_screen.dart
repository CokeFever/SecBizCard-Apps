import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/countries.dart';

import 'package:secbizcard/features/auth/data/auth_repository.dart';
import 'package:secbizcard/features/profile/data/profile_repository.dart';
import 'package:secbizcard/features/verification/data/phone_verification_repository.dart';

class PhoneVerificationScreen extends ConsumerStatefulWidget {
  final String? initialPhoneNumber;

  const PhoneVerificationScreen({super.key, this.initialPhoneNumber});

  @override
  ConsumerState<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState
    extends ConsumerState<PhoneVerificationScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _verificationId;
  bool _isLoading = false;
  bool _codeSent = false;
  String? _errorMessage;
  String _completePhoneNumber = '';
  String _initialCountryCode = 'TW';
  
  Timer? _timeoutTimer;
  Timer? _resendTimer;
  int _resendCountdown = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhoneNumber != null &&
        widget.initialPhoneNumber!.isNotEmpty) {
      String phone = widget.initialPhoneNumber!;

      // Handle numbers with '+' prefix correctly
      if (phone.startsWith('+')) {
        _completePhoneNumber = phone; // Correct string to send to Firebase

        // Find best matching country by dial code
        // We look for longest match first (+1 vs +11, etc.)
        Country? bestMatch;
        int longestMatch = 0;

        for (final country in countries) {
          final dialCode = '+${country.dialCode}';
          if (phone.startsWith(dialCode)) {
            if (dialCode.length > longestMatch) {
              longestMatch = dialCode.length;
              bestMatch = country;
            }
          }
        }

        if (bestMatch != null) {
          _initialCountryCode = bestMatch.code;
          phone = phone.substring(longestMatch);
        }
      } else {
        // Fallback for TW
        if (phone.startsWith('0')) {
          phone = phone.substring(1);
        }
        _completePhoneNumber = '+886$phone'; // Correct string to send to Firebase
      }
      _phoneController.text = phone;
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _resendTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        if (_resendCountdown > 0) {
          setState(() {
            _resendCountdown--;
          });
        } else {
          timer.cancel();
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _sendVerificationCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // 60-second safety timeout in case Firebase silently drops the request
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 45), () {
      if (mounted && _isLoading && !_codeSent) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'SMS request timed out. The number might be already used, invalid, or blocked by the server.';
        });
      }
    });

    final repository = ref.read(phoneVerificationRepositoryProvider);

    final result = await repository.sendVerificationCode(
      phoneNumber: _completePhoneNumber,
      onCodeSent: (verificationId) {
        _timeoutTimer?.cancel();
        if (mounted) {
          setState(() {
            _verificationId = verificationId;
            _codeSent = true;
            _isLoading = false;
          });
          _startResendTimer();
        }
      },
      onError: (error) {
        _timeoutTimer?.cancel();
        if (mounted) {
          setState(() {
            _errorMessage = error;
            _isLoading = false;
          });
        }
      },
      onVerificationCompleted: (credential) async {
        _timeoutTimer?.cancel();
        // Firebase auto-verification completed (instant verification)
        // Wait briefly to ensure the OTP screen is visible, so user sees what's happening
        await Future.delayed(const Duration(milliseconds: 500));

        // Only proceed if we're still on this screen
        if (!mounted) return;

        setState(() {
          _isLoading = true;
          _codeSent = true; // Show OTP screen briefly
        });

        try {
          // Update phone directly
          final user = ref.read(authRepositoryProvider).getCurrentUser();
          if (user != null) {
            await user.updatePhoneNumber(credential);
            await ref
                .read(profileRepositoryProvider)
                .markPhoneAsVerified(user.uid, _completePhoneNumber);
          }

          if (mounted) {
            // Show success message briefly before closing
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Phone verified automatically!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
            // Invalidate profile provider to refresh profile screen
            ref.invalidate(userProfileProvider);
            Navigator.of(context).pop(true);
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _errorMessage = e.toString();
              _isLoading = false;
              _codeSent = false; // Reset to allow retrying
            });
          }
        }
      },
    );

    result.fold(
      (failure) {
        setState(() {
          _errorMessage = failure.message;
          _isLoading = false;
        });
      },
      (_) {
        // Success handled in onCodeSent callback
      },
    );
  }

  Future<void> _verifyCode() async {
    if (_otpController.text.length != 6) {
      setState(() {
        _errorMessage = 'Please enter 6-digit code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final repository = ref.read(phoneVerificationRepositoryProvider);

    final result = await repository.verifyCode(
      verificationId: _verificationId!,
      smsCode: _otpController.text,
    );

    result.fold(
      (failure) {
        setState(() {
          _errorMessage = failure.message;
          _isLoading = false;
        });
      },
      (_) async {
        // Verification successful
        // Sync to Profile in Firestore
        final user = ref.read(authRepositoryProvider).getCurrentUser();
        if (user != null) {
          await ref
              .read(profileRepositoryProvider)
              .markPhoneAsVerified(user.uid, _completePhoneNumber);
        }

        if (mounted) {
          // Invalidate profile provider to refresh profile screen
          ref.invalidate(userProfileProvider);
          Navigator.of(context).pop(true); // Return true to indicate success
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Verify Phone Number',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_codeSent) ...[
                Text(
                  'Enter your phone number',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'We\'ll send you a verification code via SMS',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),
                IntlPhoneField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  initialCountryCode: _initialCountryCode,
                  onChanged: (phone) {
                    _completePhoneNumber = phone.completeNumber;
                  },
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
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
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendVerificationCode,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Send Code',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ] else ...[
                Text(
                  'Enter verification code',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'We sent a 6-digit code to $_completePhoneNumber',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                  decoration: InputDecoration(
                    hintText: '------',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    counterText: '',
                  ),
                  onChanged: (value) {
                    // Only auto-verify if exactly 6 digits and all numeric
                    if (value.length == 6 &&
                        RegExp(r'^\d{6}$').hasMatch(value)) {
                      _verifyCode();
                    }
                  },
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 24),
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
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyCode,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Verify',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Didn't receive the code? ",
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                    TextButton(
                      onPressed:
                          (_resendCountdown > 0 || _isLoading)
                              ? null
                              : _sendVerificationCode,
                      child: Text(
                        _resendCountdown > 0
                            ? 'Resend in ${_resendCountdown}s'
                            : 'Resend Code',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _codeSent = false;
                      _verificationId = null;
                      _otpController.clear();
                      _errorMessage = null;
                      _timeoutTimer?.cancel();
                      _resendTimer?.cancel();
                    });
                  },
                  child: Text(
                    'Change phone number',
                    style: GoogleFonts.inter(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
