import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  /// Wipe local DB after corruption (inspections will be lost).
  Future<void> reset() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'carguard.db');
    await deleteDatabase(path);
    _db = await _open();
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'carguard.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _ensureVinCacheTable(db);
        }
      },
      onOpen: (db) async {
        await _ensureVinCacheTable(db);
      },
    );
  }

  Future<void> _ensureVinCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS vin_decode_cache (
        vin TEXT PRIMARY KEY,
        payload_json TEXT NOT NULL,
        fetched_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE inspections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        make TEXT NOT NULL,
        model TEXT NOT NULL,
        variant TEXT NOT NULL,
        dealer_name TEXT,
        delivery_date TEXT,
        status TEXT NOT NULL,
        score INTEGER,
        created_at TEXT NOT NULL,
        summary TEXT,
        recommendations TEXT,
        dealer_notes TEXT,
        verdict TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        inspection_id INTEGER NOT NULL,
        category TEXT NOT NULL,
        local_path TEXT NOT NULL,
        analysis_json TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (inspection_id) REFERENCES inspections(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE findings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        inspection_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        severity TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        confidence INTEGER,
        FOREIGN KEY (inspection_id) REFERENCES inspections(id)
      )
    ''');
    await _ensureVinCacheTable(db);
  }
}
