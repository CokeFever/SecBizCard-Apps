import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:secbizcard/core/database/database_helper.dart';

part 'handshake_history_repository.g.dart';

enum HandshakeRequestStatus {
  pending,
  approved,
  rejected,
  missed,
  expired
}

class HandshakeHistoryRecord {
  final int? id;
  final String sessionId;
  final String? senderUid;
  final String? senderName;
  final String? photoUrl;
  final HandshakeRequestStatus status;
  final DateTime timestamp;
  final String? receiverProfileJson; // Full JSON for approval later

  HandshakeHistoryRecord({
    this.id,
    required this.sessionId,
    this.senderUid,
    this.senderName,
    this.photoUrl,
    required this.status,
    required this.timestamp,
    this.receiverProfileJson,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sessionId': sessionId,
      'senderUid': senderUid,
      'senderName': senderName,
      'photoUrl': photoUrl,
      'status': status.name.toUpperCase(),
      'timestamp': timestamp.toIso8601String(),
      'receiverProfileJson': receiverProfileJson,
    };
  }

  factory HandshakeHistoryRecord.fromMap(Map<String, dynamic> map) {
    return HandshakeHistoryRecord(
      id: map['id'] as int?,
      sessionId: map['sessionId'] as String,
      senderUid: map['senderUid'] as String?,
      senderName: map['senderName'] as String?,
      photoUrl: map['photoUrl'] as String?,
      status: HandshakeRequestStatus.values.firstWhere(
        (e) => e.name.toUpperCase() == map['status'],
        orElse: () => HandshakeRequestStatus.pending,
      ),
      timestamp: DateTime.parse(map['timestamp'] as String),
      receiverProfileJson: map['receiverProfileJson'] as String?,
    );
  }
}

@riverpod
HandshakeHistoryRepository handshakeHistoryRepository(Ref ref) {
  return HandshakeHistoryRepository(DatabaseHelper.instance);
}

@riverpod
Future<int> pendingHandshakeCount(Ref ref) async {
  final repo = ref.watch(handshakeHistoryRepositoryProvider);
  return repo.getPendingCount();
}

class HandshakeHistoryRepository {
  final DatabaseHelper _dbHelper;

  HandshakeHistoryRepository(this._dbHelper);

  Future<void> logRequest(HandshakeHistoryRecord record) async {
    final db = await _dbHelper.database;
    await db.insert('handshake_requests', record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateStatus(String sessionId, String? senderUid, HandshakeRequestStatus status) async {
    final db = await _dbHelper.database;
    await db.update(
      'handshake_requests',
      {'status': status.name.toUpperCase()},
      where: 'sessionId = ? AND (senderUid = ? OR senderUid IS NULL)',
      whereArgs: [sessionId, senderUid],
    );
  }

  Future<List<HandshakeHistoryRecord>> getHistory() async {
    final db = await _dbHelper.database;
    final maps = await db.query('handshake_requests', orderBy: 'timestamp DESC');
    return maps.map((m) => HandshakeHistoryRecord.fromMap(m)).toList();
  }

  Future<void> clearHistory() async {
    final db = await _dbHelper.database;
    await db.delete('handshake_requests');
  }

  Future<int> getPendingCount() async {
    final db = await _dbHelper.database;
    final tenMinutesAgo = DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String();
    
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM handshake_requests WHERE status = ? AND timestamp > ?',
      [HandshakeRequestStatus.pending.name.toUpperCase(), tenMinutesAgo],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}

// Provider for fetching history
@riverpod
Future<List<HandshakeHistoryRecord>> handshakeHistory(Ref ref) {
  return ref.watch(handshakeHistoryRepositoryProvider).getHistory();
}
