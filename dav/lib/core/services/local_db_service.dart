import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

class LocalDbService {
  static final LocalDbService _instance = LocalDbService._internal();
  factory LocalDbService() => _instance;
  LocalDbService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'digipress_local.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Downloads Table
    await db.execute('''
      CREATE TABLE downloads (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pdf_id INTEGER NOT NULL UNIQUE,
        title TEXT NOT NULL,
        file_url TEXT NOT NULL,
        local_path TEXT NOT NULL,
        category TEXT,
        download_timestamp TEXT NOT NULL
      )
    ''');

    // Reading History Table
    await db.execute('''
      CREATE TABLE reading_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pdf_id INTEGER NOT NULL UNIQUE,
        title TEXT NOT NULL,
        file_url TEXT NOT NULL,
        last_opened TEXT NOT NULL,
        category TEXT
      )
    ''');
  }

  // ── Downloads ─────────────────────────────────────────────────────────────

  Future<void> insertDownload(Map<String, dynamic> data) async {
    final db = await database;
    try {
      await db.insert(
        'downloads',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error inserting download: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getDownloads() async {
    final db = await database;
    return await db.query('downloads', orderBy: 'download_timestamp DESC');
  }

  Future<void> deleteDownload(int pdfId) async {
    final db = await database;
    await db.delete('downloads', where: 'pdf_id = ?', whereArgs: [pdfId]);
  }

  Future<Map<String, dynamic>?> getDownload(int pdfId) async {
    final db = await database;
    final res = await db.query('downloads', where: 'pdf_id = ?', whereArgs: [pdfId], limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  Future<void> clearDownloads() async {
    final db = await database;
    await db.delete('downloads');
  }

  // ── Reading History ───────────────────────────────────────────────────────

  Future<void> insertHistory(Map<String, dynamic> data) async {
    final db = await database;
    try {
      await db.insert(
        'reading_history',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error inserting history: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    final db = await database;
    return await db.query('reading_history', orderBy: 'last_opened DESC');
  }

  Future<void> clearHistory() async {
    final db = await database;
    await db.delete('reading_history');
  }
}
