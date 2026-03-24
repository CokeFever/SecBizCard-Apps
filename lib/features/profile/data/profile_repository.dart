import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:secbizcard/features/auth/data/auth_repository.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:secbizcard/core/errors/failure.dart';
import 'package:secbizcard/features/profile/data/datasources/profile_local_datasource.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';

part 'profile_repository.g.dart';

@riverpod
ProfileRepository profileRepository(Ref ref) {
  return ProfileRepository(ref.watch(profileLocalDataSourceProvider));
}

@riverpod
Stream<UserProfile?> userProfile(Ref ref) async* {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) {
    yield null;
    return;
  }

  final repo = ref.watch(profileRepositoryProvider);
  final result = await repo.getUser(user.uid);

  yield* result.fold(
    (failure) async* {
      // Profile not found in local storage, create from Firebase Auth
      final newProfile = UserProfile(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? 'User',
        photoUrl: user.photoURL,
        createdAt: DateTime.now(),
        emailVerified: user.emailVerified,
        emailVerifiedAt: user.emailVerified ? DateTime.now() : null,
      );

      // Save to local storage
      await repo.createOrUpdateUser(newProfile);

      yield newProfile;
    },
    (profile) async* {
      // Sync Google/Auth photoUrl if local is missing
      if (profile.photoUrl == null && user.photoURL != null) {
        final updated = profile.copyWith(photoUrl: user.photoURL);
        await repo.createOrUpdateUser(updated);
        yield updated;
      } else {
        yield profile;
      }
    },
  );
}

class ProfileRepository {
  final ProfileLocalDataSource _localDataSource;

  ProfileRepository(this._localDataSource);

  Future<Either<Failure, UserProfile>> getUser(String uid) async {
    try {
      final localUser = await _localDataSource.getUser(uid);
      if (localUser != null) {
        return Right(localUser);
      }
      return const Left(GeneralFailure('User not found'));
    } catch (e) {
      return Left(GeneralFailure('Local db error: $e'));
    }
  }

  Future<Either<Failure, Unit>> createOrUpdateUser(UserProfile user) async {
    try {
      // 1. Move temporary image files to persistent storage if needed
      UserProfile processedUser = user;
      
      processedUser = await _persistImageIfNeeded(processedUser, (u) => u.photoUrl, 'profile');
      processedUser = await _persistImageIfNeeded(processedUser, (u) => u.originalImagePath, 'contacts');
      processedUser = await _persistImageIfNeeded(processedUser, (u) => u.flatImagePath, 'contacts');
      processedUser = await _persistImageIfNeeded(processedUser, (u) => u.cardFrontPath, 'profile');
      processedUser = await _persistImageIfNeeded(processedUser, (u) => u.cardBackPath, 'profile');

      // 2. Auto-detect business email domain
      UserProfile updatedUser = processedUser;
      if (processedUser.email != null && processedUser.email!.isNotEmpty) {
        final businessDomain = _detectBusinessEmail(processedUser.email!);
        if (businessDomain != null &&
            businessDomain != processedUser.businessEmailDomain) {
          updatedUser = processedUser.copyWith(businessEmailDomain: businessDomain);
        }
      }

      // 3. Save to Local Only
      await _localDataSource.saveUser(updatedUser);

      return const Right(unit);
    } catch (e) {
      return Left(GeneralFailure(e.toString()));
    }
  }

  Future<UserProfile> _persistImageIfNeeded(
    UserProfile user,
    String? Function(UserProfile) getPath,
    String subDir,
  ) async {
    final path = getPath(user);
    if (path == null || path.isEmpty || path.startsWith('http') || path.startsWith('zip://')) {
      return user;
    }

    final file = File(path);
    if (!file.existsSync()) return user;

    final appDir = await getApplicationDocumentsDirectory();
    final tempDir = await getTemporaryDirectory();

    // Check if path is in temp directory
    if (path.startsWith(tempDir.path)) {
      final fileName = p.basename(path);
      final targetDir = Directory(p.join(appDir.path, subDir));
      if (!targetDir.existsSync()) {
        await targetDir.create(recursive: true);
      }
      
      final targetPath = p.join(targetDir.path, fileName);
      await file.copy(targetPath);
      
      // Return updated user with new path
      if (getPath(user) == user.photoUrl) return user.copyWith(photoUrl: targetPath);
      if (getPath(user) == user.originalImagePath) return user.copyWith(originalImagePath: targetPath);
      if (getPath(user) == user.flatImagePath) return user.copyWith(flatImagePath: targetPath);
      if (getPath(user) == user.cardFrontPath) return user.copyWith(cardFrontPath: targetPath);
      if (getPath(user) == user.cardBackPath) return user.copyWith(cardBackPath: targetPath);
    }

    return user;
  }

  Future<Either<Failure, Unit>> markEmailAsVerified(String uid) async {
    try {
      final user = await _localDataSource.getUser(uid);
      if (user != null) {
        await _localDataSource.saveUser(
          user.copyWith(emailVerified: true, emailVerifiedAt: DateTime.now()),
        );
        return const Right(unit);
      }
      return const Left(GeneralFailure('User not found'));
    } catch (e) {
      return Left(GeneralFailure(e.toString()));
    }
  }

  Future<Either<Failure, Unit>> markPhoneAsVerified(
    String uid,
    String phoneNumber,
  ) async {
    try {
      final user = await _localDataSource.getUser(uid);
      if (user != null) {
        await _localDataSource.saveUser(
          user.copyWith(
            phoneVerified: true,
            phoneVerifiedAt: DateTime.now(),
            phone: phoneNumber,
          ),
        );
        return const Right(unit);
      }
      return const Left(GeneralFailure('User not found'));
    } catch (e) {
      return Left(GeneralFailure(e.toString()));
    }
  }

  /// Detects if an email is a business email and returns the domain
  /// Returns null if it's a free email provider
  String? _detectBusinessEmail(String email) {
    const freeEmailDomains = {
      'gmail.com',
      'googlemail.com',
      'outlook.com',
      'hotmail.com',
      'live.com',
      'msn.com',
      'yahoo.com',
      'yahoo.co.uk',
      'ymail.com',
      'icloud.com',
      'me.com',
      'mac.com',
      'aol.com',
      'protonmail.com',
      'proton.me',
      'mail.com',
      'gmx.com',
      'zoho.com',
      'tutanota.com',
      'fastmail.com',
      'qq.com',
      '163.com',
      '126.com',
      'sina.com',
      'sohu.com',
    };

    final parts = email.split('@');
    if (parts.length != 2) return null;

    final domain = parts[1].toLowerCase();
    if (freeEmailDomains.contains(domain)) return null;

    return domain;
  }

  Future<Either<Failure, Unit>> updateFcmToken(String uid, String token) async {
    try {
      // 1. Update Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': token,
      }, SetOptions(merge: true));

      // 2. Update Local
      final user = await _localDataSource.getUser(uid);
      if (user != null) {
        await _localDataSource.saveUser(user.copyWith(fcmToken: token));
      }
      return const Right(unit);
    } catch (e) {
      return Left(GeneralFailure(e.toString()));
    }
  }
}
