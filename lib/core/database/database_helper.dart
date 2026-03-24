import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const _databaseName = "ixo_app.db";
  static const _databaseVersion = 12;

  // Singleton pattern
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    // User Table
    // Note: contextsJson and booleans need to be handled carefully in DataSource
    await db.execute('''
      CREATE TABLE users (
        uid TEXT PRIMARY KEY,
        email TEXT NOT NULL,
        displayName TEXT NOT NULL,
        photoUrl TEXT,
        title TEXT,
        company TEXT,
        department TEXT,
        phone TEXT,
        address TEXT,
        createdAt TEXT NOT NULL,
        avatarDriveFileId TEXT,
        contextsJson TEXT,
        customFields TEXT,
        phoneVerified INTEGER,
        emailVerified INTEGER,
        businessEmailDomain TEXT,
        phoneVerifiedAt TEXT,
        emailVerifiedAt TEXT,
        isOnboardingComplete INTEGER,
        fcmToken TEXT,
        originalImagePath TEXT,
        flatImagePath TEXT,
        source TEXT,
        mobile TEXT,
        website TEXT,
        cardFrontPath TEXT,
        cardBackPath TEXT,
        cardFrontDriveFileId TEXT,
        cardBackDriveFileId TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE saved_contacts (
        contact_uid TEXT PRIMARY KEY,
        saved_at TEXT NOT NULL
      )
    ''');
    
    await db.execute('''
      CREATE TABLE handshake_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sessionId TEXT NOT NULL,
        senderUid TEXT,
        senderName TEXT,
        photoUrl TEXT,
        status TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        receiverProfileJson TEXT,
        UNIQUE(sessionId, senderUid)
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS users');
      await _onCreate(db, newVersion);
    } else {
      if (oldVersion < 3) {
        await db.execute('ALTER TABLE users ADD COLUMN customFields TEXT');
      }
      if (oldVersion < 4) {
        await db.execute('ALTER TABLE users ADD COLUMN username TEXT');
        await db.execute('ALTER TABLE users ADD COLUMN usernameSetAt TEXT');
      }
      if (oldVersion < 5) {
        await db.execute('''
          CREATE TABLE saved_contacts (
            contact_uid TEXT PRIMARY KEY,
            saved_at TEXT NOT NULL
          )
        ''');
      }
      if (oldVersion < 6) {
        await db.execute('ALTER TABLE users ADD COLUMN fcmToken TEXT');
      }
      if (oldVersion < 7) {
        await db.execute('ALTER TABLE users ADD COLUMN department TEXT');
        await db.execute('ALTER TABLE users ADD COLUMN address TEXT');
        await db.execute('ALTER TABLE users ADD COLUMN originalImagePath TEXT');
        await db.execute('ALTER TABLE users ADD COLUMN flatImagePath TEXT');
        await db.execute(
          "ALTER TABLE users ADD COLUMN source TEXT DEFAULT 'handshake'",
        );
      }
      if (oldVersion < 8) {
        await db.execute('ALTER TABLE users ADD COLUMN mobile TEXT');
        await db.execute('ALTER TABLE users ADD COLUMN website TEXT');
      }
      // Migration 9: Re-attempt mobile/website for users who upgraded from v7 to v8 before the schema fix
      if (oldVersion < 9) {
        // Safely add columns if they don't exist
        await _safeAddColumn(db, 'users', 'mobile', 'TEXT');
        await _safeAddColumn(db, 'users', 'website', 'TEXT');
      }
      
      if (oldVersion < 10) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS handshake_requests (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sessionId TEXT NOT NULL,
            senderUid TEXT,
            senderName TEXT,
            photoUrl TEXT,
            status TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            receiverProfileJson TEXT,
            UNIQUE(sessionId, senderUid)
          )
        ''');
      }
      
      if (oldVersion < 11) {
        await _safeAddColumn(db, 'handshake_requests', 'receiverProfileJson', 'TEXT');
      }

      if (oldVersion < 12) {
        await _safeAddColumn(db, 'users', 'cardFrontPath', 'TEXT');
        await _safeAddColumn(db, 'users', 'cardBackPath', 'TEXT');
        await _safeAddColumn(db, 'users', 'cardFrontDriveFileId', 'TEXT');
        await _safeAddColumn(db, 'users', 'cardBackDriveFileId', 'TEXT');
      }
    }
  }

  Future<void> _safeAddColumn(
    Database db,
    String table,
    String column,
    String type,
  ) async {
    // Check if column exists
    final result = await db.rawQuery('PRAGMA table_info($table)');
    final columnExists = result.any((row) => row['name'] == column);
    if (!columnExists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }

  /// Deletes all user data from the local database.
  /// Used during account deletion to comply with Apple's data deletion requirements.
  Future<void> deleteAllData() async {
    final db = await database;
    await db.delete('users');
    await db.delete('saved_contacts');
    await db.delete('handshake_requests');
  }
}
