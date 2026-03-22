import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:secbizcard/core/errors/failure.dart';

part 'phone_verification_repository.g.dart';

@riverpod
PhoneVerificationRepository phoneVerificationRepository(Ref ref) {
  return PhoneVerificationRepository(FirebaseAuth.instance);
}

class PhoneVerificationRepository {
  final FirebaseAuth _auth;

  PhoneVerificationRepository(this._auth);

  /// Send SMS verification code to phone number
  Future<Either<Failure, String>> sendVerificationCode({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    required Function(PhoneAuthCredential credential) onVerificationCompleted,
  }) async {
    try {
      // Don't wait for the return of verifyPhoneNumber, it's a void method that triggers callbacks
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          onVerificationCompleted(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          String message = e.message ?? 'Verification failed';
          if (e.code == 'invalid-phone-number') {
            message = 'The provided phone number is not valid.';
          } else if (e.code == 'quota-exceeded') {
            message = 'SMS quota exceeded. Please try again later.';
          } else if (e.code == 'too-many-requests') {
            message = 'Too many requests. Please try again later.';
          } else if (e.code == 'credential-already-in-use') {
            message = 'This phone number is already linked to another account.';
          }
          onError('[$e.code] $message');
        },
        codeSent: (String verId, int? resendToken) {
          onCodeSent(verId);
        },
        codeAutoRetrievalTimeout: (String verId) {
          // Auto-retrieval timed out, but verificationId might still be valid for manual entry
        },
      );

      return const Right(
        'Verification started',
      ); // Return immediate success of *starting* the process
    } on FirebaseAuthException catch (e) {
      return Left(ServerFailure(e.message ?? 'Phone verification error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  /// Verify the SMS code entered by user
  Future<Either<Failure, Unit>> verifyCode({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      // Link credential to current user (don't sign in as new user)
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await currentUser.updatePhoneNumber(credential);
        return const Right(unit);
      } else {
        return const Left(AuthFailure('No user signed in'));
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-verification-code') {
        return const Left(ValidationFailure('Invalid verification code'));
      }
      if (e.code == 'credential-already-in-use') {
        return const Left(
          ValidationFailure(
            'This phone number is already linked to another account. Please use a different number.',
          ),
        );
      }
      return Left(ServerFailure(e.message ?? 'Verification failed'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  /// Get current user's verified phone number
  String? getVerifiedPhoneNumber() {
    return _auth.currentUser?.phoneNumber;
  }
}
