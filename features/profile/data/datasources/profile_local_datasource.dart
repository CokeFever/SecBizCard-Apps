import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite/sqflite.dart';

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

      return UserProfile.fromJson(map);
    }
    return null;
  }
}
