import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as fire_auth;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:google_sign_in/google_sign_in.dart' as google_sign_in;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/people/v1.dart' as people;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:secbizcard/core/database/database_helper.dart';
import 'package:secbizcard/core/errors/failure.dart';
import 'package:secbizcard/core/services/backup_reminder_service.dart';
import 'package:secbizcard/features/profile/data/profile_repository.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';
import 'package:secbizcard/features/settings/data/magic_word_service.dart';
import 'package:secbizcard/features/settings/data/ocr_settings_service.dart';

part 'auth_repository.g.dart';

final authInitializationStateProvider = StateProvider<bool>((ref) => true);

// The Web client ID from Firebase console (client_type: 3 in
// google-services.json). Required on BOTH GoogleSignIn instances so Firebase
// can link the Google credential to the correct web client.
const String _kServerClientId =
    '769422548283-rvuciu2cmfj9149fudj9q59pql4ofo8q.apps.googleusercontent.com';

/// Dedicated GoogleSignIn instance for Drive backup/restore.
///
/// This instance declares ONLY the `drive.file` scope at construction and is
/// the only one injected into [DriveRepository] and [AuthRepository]. Keeping
/// its scope set fixed to drive.file means the Drive sign-in / token flow can
/// never surface or attach the pending-verification `contacts` scope — which is
/// what previously poisoned the shared grant and made the drive.file token
/// request fail with GMS Auth `BAD_REQUEST`, breaking backup/restore.
@riverpod
google_sign_in.GoogleSignIn driveGoogleSignIn(Ref ref) {
  return google_sign_in.GoogleSignIn(
    serverClientId: _kServerClientId,
    scopes: [drive.DriveApi.driveFileScope],
  );
}

/// Dedicated GoogleSignIn instance for Save-to-Google-Contacts.
///
/// A SEPARATE GoogleSignIn object from [driveGoogleSignIn] so the two features'
/// grants stay independent: requesting the `contacts` scope on this instance
/// never touches the Drive instance's drive.file token request.
@riverpod
google_sign_in.GoogleSignIn contactsGoogleSignIn(Ref ref) {
  return google_sign_in.GoogleSignIn(
    serverClientId: _kServerClientId,
    scopes: [people.PeopleServiceApi.contactsScope],
  );
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  return AuthRepository(
    fire_auth.FirebaseAuth.instance,
    ref.watch(driveGoogleSignInProvider),
    ref,
    contactsGoogleSignIn: ref.watch(contactsGoogleSignInProvider),
  );
}

@riverpod
Stream<fire_auth.User?> authState(Ref ref) {
  return fire_auth.FirebaseAuth.instance.authStateChanges();
}

class AuthRepository {
  final fire_auth.FirebaseAuth _firebaseAuth;
  // Drive instance (login / silent sign-in / Google re-auth all run through
  // this one — they only ever touch basic + drive.file scopes).
  final google_sign_in.GoogleSignIn _googleSignIn;
  // Contacts instance, held only so signOut()/deleteAccount() can fully clear
  // Google state across BOTH grants.
  final google_sign_in.GoogleSignIn _contactsGoogleSignIn;

  AuthRepository(
    this._firebaseAuth,
    this._googleSignIn,
    this._ref, {
    required google_sign_in.GoogleSignIn contactsGoogleSignIn,
  }) : _contactsGoogleSignIn = contactsGoogleSignIn {
    _init();
  }

  final Ref _ref;

  void _init() async {
    debugPrint('[Auth] _init started');
    try {
      // Fast path: check if Firebase has a cached user (avoids stream wait)
      final cachedUser = _firebaseAuth.currentUser;
      if (cachedUser != null) {
        debugPrint('[Auth] User ${cachedUser.uid} found from cache (fast path)');
      } else {
        // No cached user — wait for auth stream (first launch or signed out)
        debugPrint('[Auth] No cached user, waiting for authStateChange...');
        final firstUser = await _firebaseAuth.authStateChanges().first.timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint('[Auth] authStateChanges().first timed out!');
            return null;
          },
        );

        if (firstUser == null) {
          debugPrint('[Auth] No user from stream. Trying silent sign-in...');
          await _trySilentSignIn();
        } else {
          debugPrint('[Auth] User ${firstUser.uid} found from stream.');
        }
      }
    } catch (e) {
      debugPrint('[Auth] Error during _init: $e');
    } finally {
      // Mark initialization as complete
      debugPrint('[Auth] Initialization complete, setting state to false');
      _ref.read(authInitializationStateProvider.notifier).state = false;
    }

    _firebaseAuth.authStateChanges().listen((user) {
      if (user != null) {
        debugPrint('[Auth] User session active: ${user.uid}');
      } else {
        debugPrint('[Auth] No active Firebase session.');
      }
    });
  }

  Future<void> _trySilentSignIn() async {
    try {
      debugPrint('[Auth] Attempting Google Silent Sign-In...');
      // Add a timeout to prevent initialization from hanging forever if silent sign-in stalls
      final googleUser = await _googleSignIn.signInSilently().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('[Auth] Google Silent Sign-In timed out');
          return null;
        },
      );
      if (googleUser != null) {
        debugPrint('[Auth] Google Silent Sign-In success: ${googleUser.email}');
        final googleAuth = await googleUser.authentication;
        final credential = fire_auth.GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await _firebaseAuth.signInWithCredential(credential);
        debugPrint('[Auth] Firebase session restored via Silent Sign-In');
      }
    } catch (e) {
      debugPrint('[Auth] Google Silent Sign-In error: $e');
    }
  }

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
        // Sign out of BOTH Google instances. They are independent GoogleSignIn
        // objects (drive.file vs contacts), so logout must clear each one to
        // fully reset Google state for the next account on this device.
        await _googleSignIn.signOut();
        await _contactsGoogleSignIn.signOut();
      }
      // Apple Sign-In does not require explicit sign-out
    } catch (e) {
      // Just log or ignore for now
    }
    // PRIVACY: wipe all local personal data on sign-out. Contacts/profile are
    // stored locally in one device-wide sqflite DB with no per-account scoping,
    // so without this the next account to sign in on this device would see the
    // previous user's contacts (cross-account leak). Contacts live on-device and
    // are recoverable from the user's Google Drive backup, so clearing here is
    // safe by design. Runs regardless of provider and even if sign-out threw,
    // so we never leave the previous user's data behind.
    try {
      await DatabaseHelper.instance.deleteAllData();
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] local data wipe on sign-out failed: $e');
    }
    // Also clear the backup-reminder bookkeeping so the next account signing in
    // on this device does not inherit the previous account's "unbacked-up
    // changes" / snooze state (those timestamps live in SharedPreferences,
    // which the DB wipe above does not touch).
    try {
      await BackupReminderService().clear();
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] backup-reminder clear on sign-out failed: $e');
    }
    // Clear the BYO Cloud Vision key from secure storage so the next account on
    // this device doesn't inherit the previous user's key. (Previously this
    // leaked — sign-out only wiped the contacts DB.) Fault-isolated: a secure
    // storage error must never abort the rest of logout.
    try {
      await OcrSettingsService(buildSecureStorage()).clearApiKey();
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] BYOK clear on sign-out failed: $e');
    }
    // Clear the backup magic word too. Combined with the DB wipe this means a
    // signed-out device holds no magicword — restoring a magicword backup after
    // sign-in requires re-entering the word (see the layered logout warning).
    try {
      await MagicWordService(buildSecureStorage()).clearMagicWord();
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] magic-word clear on sign-out failed: $e');
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

      // Sign out of Google if applicable — clear BOTH instances so no Google
      // grant (drive.file or contacts) lingers after account deletion.
      if (provider == 'google.com') {
        await _googleSignIn.signOut();
        await _contactsGoogleSignIn.signOut();
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
