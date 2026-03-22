import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as fire_auth;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:google_sign_in/google_sign_in.dart' as google_sign_in;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:secbizcard/core/errors/failure.dart';
import 'package:secbizcard/features/profile/data/profile_repository.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';

part 'auth_repository.g.dart';

@riverpod
google_sign_in.GoogleSignIn googleSignIn(Ref ref) {
  return google_sign_in.GoogleSignIn(
    // The Web client ID from Firebase console (client_type: 3 in google-services.json)
    serverClientId: '769422548283-rvuciu2cmfj9149fudj9q59pql4ofo8q.apps.googleusercontent.com',
  );
}

@riverpod
AuthRepository authRepository(Ref ref) {
  return AuthRepository(
    fire_auth.FirebaseAuth.instance,
    ref.watch(googleSignInProvider),
  );
}

@riverpod
Stream<fire_auth.User?> authState(Ref ref) {
  return fire_auth.FirebaseAuth.instance.authStateChanges();
}

class AuthRepository {
  final fire_auth.FirebaseAuth _firebaseAuth;
  final google_sign_in.GoogleSignIn _googleSignIn;

  AuthRepository(this._firebaseAuth, this._googleSignIn);

  fire_auth.User? getCurrentUser() {
    return _firebaseAuth.currentUser;
  }

  /// Returns the provider ID used to sign in for the current session (e.g. 'google.com', 'apple.com').
  Future<String?> _getSignInProvider() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    
    try {
      final idTokenResult = await user.getIdTokenResult();
      final signInProvider = idTokenResult.signInProvider;
      if (signInProvider != null && signInProvider.isNotEmpty) {
        return signInProvider;
      }
    } catch (e) {
      debugPrint('[Auth] Error getting idTokenResult: $e');
    }

    // Fallback if idTokenResult fails
    for (final info in user.providerData) {
      if (info.providerId == 'google.com') return 'google.com';
      if (info.providerId == 'apple.com') return 'apple.com';
    }
    return null;
  }

  /// Generates a random nonce string for Apple Sign-In.
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  /// Returns the SHA256 hash of [input].
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<Either<Failure, fire_auth.User>> signInWithGoogle(
    ProfileRepository profileRepo,
  ) async {
    try {
      final google_sign_in.GoogleSignInAccount? googleUser = await _googleSignIn
          .signIn();
      if (googleUser == null) {
        // User canceled the sign-in flow
        return const Left(AuthFailure('Google Sign-In canceled'));
      }

      final google_sign_in.GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final fire_auth.AuthCredential credential =
          fire_auth.GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );

      return _completeSignIn(credential, profileRepo);
    } on fire_auth.FirebaseAuthException catch (e) {
      return Left(AuthFailure(e.message ?? 'Firebase Authentication Failed'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, fire_auth.User>> signInWithApple(
    ProfileRepository profileRepo,
  ) async {
    try {
      if (!kIsWeb && !Platform.isIOS) {
        // Use Firebase's native web view flow for Android
        final provider = fire_auth.OAuthProvider('apple.com');
        provider.addScope('email');
        provider.addScope('name');
        
        debugPrint('[Auth] Using Firebase native OAuthProvider for Android Apple Sign-In');
        final credential = await _firebaseAuth.signInWithProvider(provider);
        return _completeSignIn(
          credential.credential!,
          profileRepo,
          displayNameOverride: credential.user?.displayName,
        );
      }

      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      debugPrint('[Auth] Starting Apple Sign-In for iOS...');

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      debugPrint('[Auth] Apple credential received. email=${appleCredential.email}, givenName=${appleCredential.givenName}');

      if (appleCredential.identityToken == null) {
        debugPrint('[Auth] Apple identityToken is null!');
        return const Left(AuthFailure('Apple Sign-In failed: no identity token received'));
      }

      final oauthCredential = fire_auth.OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );

      debugPrint('[Auth] Firebase credential created, signing in...');

      return _completeSignIn(
        oauthCredential,
        profileRepo,
        displayNameOverride: appleCredential.givenName != null
            ? '${appleCredential.givenName} ${appleCredential.familyName ?? ''}'
                .trim()
            : null,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      debugPrint('[Auth] Apple SignIn authorization error: ${e.code} - ${e.message}');
      if (e.code == AuthorizationErrorCode.canceled) {
        return const Left(AuthFailure('Apple Sign-In canceled'));
      }
      return Left(AuthFailure(e.message));
    } on fire_auth.FirebaseAuthException catch (e) {
      debugPrint('[Auth] Firebase auth error: ${e.code} - ${e.message}');
      return Left(AuthFailure(e.message ?? 'Firebase Authentication Failed'));
    } catch (e, stackTrace) {
      debugPrint('[Auth] Unexpected error during Apple Sign-In: $e');
      debugPrint('[Auth] Stack trace: $stackTrace');
      return Left(ServerFailure(e.toString()));
    }
  }

  /// Shared sign-in completion logic for both Google and Apple.
  Future<Either<Failure, fire_auth.User>> _completeSignIn(
    fire_auth.AuthCredential credential,
    ProfileRepository profileRepo, {
    String? displayNameOverride,
  }) async {
    final fire_auth.UserCredential userCredential = await _firebaseAuth
        .signInWithCredential(credential);

    final user = userCredential.user;
    debugPrint('[Auth] signInWithCredential complete. user=${user?.uid}');

    if (user != null) {
      // Check if user exists in Firestore, if not create
      final userDoc = await profileRepo.getUser(user.uid);
      if (userDoc.isLeft()) {
        // User doesn't exist (assuming 404 returns Failure), create new
        final newProfile = UserProfile(
          uid: user.uid,
          email: user.email ?? '',
          displayName: displayNameOverride ?? user.displayName ?? 'New User',
          photoUrl: user.photoURL,
          createdAt: DateTime.now(),
          emailVerified: true,
          emailVerifiedAt: DateTime.now(),
        );
        await profileRepo.createOrUpdateUser(newProfile);
        debugPrint('[Auth] New user profile created');
      } else {
        debugPrint('[Auth] Existing user found');
      }

      return Right(user);
    } else {
      return const Left(AuthFailure('User is null after sign in'));
    }
  }

  Future<void> signOut() async {
    try {
      final provider = await _getSignInProvider();
      await _firebaseAuth.signOut();
      if (provider == 'google.com') {
        await _googleSignIn.signOut();
      }
      // Apple Sign-In does not require explicit sign-out
    } catch (e) {
      // Just log or ignore for now
    }
  }

  /// Deletes the user's Firebase Auth account.
  /// Re-authenticates with the original provider first (Firebase requires recent sign-in).
  Future<Either<Failure, Unit>> deleteAccount() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        return const Left(AuthFailure('No user is currently signed in'));
      }

      final provider = await _getSignInProvider();

      if (provider == 'apple.com') {
        if (!kIsWeb && !Platform.isIOS) {
          final authProvider = fire_auth.OAuthProvider('apple.com');
          authProvider.addScope('email');
          authProvider.addScope('name');
          // No need to wrap in credential, we can reauthenticate directly with the provider
          await user.reauthenticateWithProvider(authProvider);
        } else {
          // Re-authenticate with Apple before deletion on iOS
          final rawNonce = _generateNonce();
          final nonce = _sha256ofString(rawNonce);

          final appleCredential = await SignInWithApple.getAppleIDCredential(
            scopes: [
              AppleIDAuthorizationScopes.email,
              AppleIDAuthorizationScopes.fullName,
            ],
            nonce: nonce,
          );

          final credential = fire_auth.OAuthProvider('apple.com').credential(
            idToken: appleCredential.identityToken,
            rawNonce: rawNonce,
            accessToken: appleCredential.authorizationCode,
          );
          await user.reauthenticateWithCredential(credential);
        }
      } else {
        // Re-authenticate with Google before deletion (default)
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          return const Left(AuthFailure('Re-authentication canceled'));
        }

        final googleAuth = await googleUser.authentication;
        final credential = fire_auth.GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await user.reauthenticateWithCredential(credential);
      }

      // Delete the Firebase Auth account
      await user.delete();

      // Sign out of Google if applicable
      if (provider == 'google.com') {
        await _googleSignIn.signOut();
      }

      return const Right(unit);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return const Left(AuthFailure('Re-authentication canceled'));
      }
      return Left(AuthFailure(e.message));
    } on fire_auth.FirebaseAuthException catch (e) {
      return Left(AuthFailure(e.message ?? 'Account deletion failed'));
    } catch (e) {
      return Left(ServerFailure('Account deletion failed: $e'));
    }
  }
}
