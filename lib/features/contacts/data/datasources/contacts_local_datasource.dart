import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite/sqflite.dart';

import 'package:secbizcard/core/database/database_helper.dart';

part 'contacts_local_datasource.g.dart';

@riverpod
ContactsLocalDataSource contactsLocalDataSource(Ref ref) {
  return ContactsLocalDataSource(DatabaseHelper.instance);
}

class ContactsLocalDataSource {
  final DatabaseHelper _dbHelper;

  ContactsLocalDataSource(this._dbHelper);

  Future<void> saveContact(String contactUid) async {
    final db = await _dbHelper.database;

    await db.insert('saved_contacts', {
      'contact_uid': contactUid,
      'saved_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteContact(String contactUid) async {
    final db = await _dbHelper.database;
    await db.delete(
      'saved_contacts',
      where: 'contact_uid = ?',
      whereArgs: [contactUid],
    );
  }

  Future<bool> isContactSaved(String contactUid) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'saved_contacts',
      where: 'contact_uid = ?',
      whereArgs: [contactUid],
    );
    return results.isNotEmpty;
  }

  Future<List<String>> getSavedContacts() async {
    final db = await _dbHelper.database;
    final results = await db.query('saved_contacts', orderBy: 'saved_at DESC');
    return results.map((row) => row['contact_uid'] as String).toList();
  }
}
