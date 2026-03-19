import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:secbizcard/core/errors/failure.dart';

part 'email_verification_repository.g.dart';

@riverpod
EmailVerificationRepository emailVerificationRepository(Ref ref) {
  return EmailVerificationRepository(FirebaseAuth.instance);
}

class EmailVerificationRepository {
  final FirebaseAuth _auth;

  EmailVerificationRepository(this._auth);

  /// Send email verification link to user's email
  Future<Either<Failure, Unit>> sendVerificationEmail() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return const Left(AuthFailure('No user signed in'));
      }

      if (user.emailVerified) {
        return const Left(ValidationFailure('Email already verified'));
      }

      await user.sendEmailVerification();
      return const Right(unit);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') {
        return const Left(
          ServerFailure('Too many requests. Please try again later.'),
        );
      }
      return Left(
        ServerFailure(e.message ?? 'Failed to send verification email'),
      );
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  /// Update email and send verification (verifyBeforeUpdateEmail)
  Future<Either<Failure, Unit>> verifyBeforeUpdateEmail(String newEmail) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return const Left(AuthFailure('No user signed in'));
      }

      // Check if trying to update to same email
      if (user.email == newEmail && user.emailVerified) {
        return const Left(ValidationFailure('Email already verified'));
      }

      await user.verifyBeforeUpdateEmail(newEmail);
      return const Right(unit);
    } on FirebaseAuthException catch (e) {
      return Left(
        ServerFailure(e.message ?? 'Failed to send verification email'),
      );
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  /// Check if current user's email is verified
  Future<Either<Failure, bool>> checkEmailVerified() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return const Left(AuthFailure('No user signed in'));
      }

      // Reload user to get latest verification status
      await user.reload();
      final updatedUser = _auth.currentUser;

      return Right(updatedUser?.emailVerified ?? false);
    } on FirebaseAuthException catch (e) {
      return Left(
        ServerFailure(e.message ?? 'Failed to check verification status'),
      );
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  /// Get current user's email verification status
  bool isEmailVerified() {
    return _auth.currentUser?.emailVerified ?? false;
  }

  /// Get current user's email
  String? getUserEmail() {
    return _auth.currentUser?.email;
  }
}
