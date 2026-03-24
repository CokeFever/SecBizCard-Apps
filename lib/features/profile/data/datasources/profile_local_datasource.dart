import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'package:secbizcard/core/database/database_helper.dart';

import 'package:secbizcard/features/profile/domain/user_profile.dart';

part 'profile_local_datasource.g.dart';

@riverpod
ProfileLocalDataSource profileLocalDataSource(Ref ref) {
  return ProfileLocalDataSource(DatabaseHelper.instance);
}

class ProfileLocalDataSource {
  final DatabaseHelper _dbHelper;

  ProfileLocalDataSource(this._dbHelper);

  Future<String> _getAppDocsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  /// Converts an absolute path to a relative path for database storage.
  /// Also repairs "legacy" absolute paths from previous playground/install sessions.
  Future<String?> _toRelativePath(String? path) async {
    if (path == null || path.isEmpty || path.startsWith('http') || path.startsWith('zip://')) {
      return path;
    }

    final appDocsDir = await _getAppDocsDir();

    // 1. Repair check: If path is absolute but contains old sandbox parts
    // iOS: .../Application/UUID/Documents/profile/photo.jpg
    // Android: .../app_flutter/profile/photo.jpg
    if (path.contains('/Documents/')) {
      final index = path.indexOf('/Documents/');
      return path.substring(index + '/Documents/'.length);
    }
    if (path.contains('/app_flutter/')) {
      final index = path.indexOf('/app_flutter/');
      return path.substring(index + '/app_flutter/'.length);
    }
    if (path.contains('/files/')) {
      final index = path.indexOf('/files/');
      return path.substring(index + '/files/'.length);
    }

    // 2. Standard relativization
    if (p.isAbsolute(path)) {
      if (path.startsWith(appDocsDir)) {
        return p.relative(path, from: appDocsDir);
      }
    }

    return path;
  }

  /// Resolves a relative path from the database to an absolute runtime path.
  Future<String?> _toAbsolutePath(String? path) async {
    if (path == null || path.isEmpty || path.startsWith('http') || path.startsWith('zip://')) {
      return path;
    }

    if (p.isAbsolute(path)) {
      // If it's already absolute, check if it's a dead sandbox path
      if (path.contains('/Documents/')) {
        final docsIndex = path.indexOf('/Documents/');
        final relativePart = path.substring(docsIndex + '/Documents/'.length);
        final appDocsDir = await _getAppDocsDir();
        return p.join(appDocsDir, relativePart);
      }
      if (path.contains('/app_flutter/')) {
        final index = path.indexOf('/app_flutter/');
        final relativePart = path.substring(index + '/app_flutter/'.length);
        final appDocsDir = await _getAppDocsDir();
        return p.join(appDocsDir, relativePart);
      }
      if (path.contains('/files/')) {
        final index = path.indexOf('/files/');
        final relativePart = path.substring(index + '/files/'.length);
        final appDocsDir = await _getAppDocsDir();
        return p.join(appDocsDir, relativePart);
      }
      return path;
    }

    final appDocsDir = await _getAppDocsDir();
    return p.join(appDocsDir, path);
  }

  Future<void> saveUser(UserProfile user) async {
    final db = await _dbHelper.database;

    final Map<String, dynamic> userMap = Map.from(user.toJson());

    userMap['phoneVerified'] = user.phoneVerified ? 1 : 0;
    userMap['emailVerified'] = user.emailVerified ? 1 : 0;
    userMap['isOnboardingComplete'] = user.isOnboardingComplete ? 1 : 0;

    if (user.contextsJson.isNotEmpty) {
      userMap['contextsJson'] = jsonEncode(user.contextsJson);
    } else {
      userMap['contextsJson'] = '{}';
    }

    if (user.customFields.isNotEmpty) {
      userMap['customFields'] = jsonEncode(user.customFields);
    } else {
      userMap['customFields'] = '{}';
    }

    // Path Portability: Save as relative paths
    userMap['photoUrl'] = await _toRelativePath(user.photoUrl);
    userMap['originalImagePath'] = await _toRelativePath(user.originalImagePath);
    userMap['flatImagePath'] = await _toRelativePath(user.flatImagePath);
    userMap['cardFrontPath'] = await _toRelativePath(user.cardFrontPath);
    userMap['cardBackPath'] = await _toRelativePath(user.cardBackPath);

    await db.insert(
      'users',
      userMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<UserProfile?> getUser(String uid) async {
    final db = await _dbHelper.database;
    final maps = await db.query('users', where: 'uid = ?', whereArgs: [uid]);

    if (maps.isNotEmpty) {
      final map = Map<String, dynamic>.from(maps.first);

      map['phoneVerified'] = (map['phoneVerified'] as int?) == 1;
      map['emailVerified'] = (map['emailVerified'] as int?) == 1;
      map['isOnboardingComplete'] = (map['isOnboardingComplete'] as int?) == 1;

      if (map['contextsJson'] is String) {
        try {
          map['contextsJson'] = jsonDecode(map['contextsJson'] as String);
        } catch (_) {
          map['contextsJson'] = {};
        }
      }

      if (map['customFields'] is String) {
        try {
          final decoded = jsonDecode(map['customFields'] as String);
          map['customFields'] = Map<String, String>.from(decoded);
        } catch (_) {
          map['customFields'] = <String, String>{};
        }
      }

      // Path Portability: Resolve back to absolute paths
      map['photoUrl'] = await _toAbsolutePath(map['photoUrl'] as String?);
      map['originalImagePath'] = await _toAbsolutePath(map['originalImagePath'] as String?);
      map['flatImagePath'] = await _toAbsolutePath(map['flatImagePath'] as String?);
      map['cardFrontPath'] = await _toAbsolutePath(map['cardFrontPath'] as String?);
      map['cardBackPath'] = await _toAbsolutePath(map['cardBackPath'] as String?);

      return UserProfile.fromJson(map);
    }
    return null;
  }
}
