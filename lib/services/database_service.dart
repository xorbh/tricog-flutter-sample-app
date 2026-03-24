import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/ecg_record.dart';
import '../models/user_profile.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  static Database? _database;

  DatabaseService._();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'cardioscan.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE ecg_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            patient_name TEXT NOT NULL,
            patient_age INTEGER NOT NULL,
            patient_gender TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            ecg_data TEXT NOT NULL,
            interpretation TEXT NOT NULL,
            severity TEXT NOT NULL,
            heart_rate INTEGER NOT NULL,
            findings TEXT NOT NULL,
            doctor_notes TEXT,
            symptoms TEXT,
            symptom_note TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE user_profile (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            date_of_birth TEXT NOT NULL,
            gender TEXT NOT NULL,
            medical_conditions TEXT NOT NULL,
            medications TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE ecg_records ADD COLUMN symptoms TEXT');
          await db.execute('ALTER TABLE ecg_records ADD COLUMN symptom_note TEXT');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS user_profile (
              id INTEGER PRIMARY KEY,
              name TEXT NOT NULL,
              date_of_birth TEXT NOT NULL,
              gender TEXT NOT NULL,
              medical_conditions TEXT NOT NULL,
              medications TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
        }
      },
    );
  }

  // ---- Profile ----

  Future<bool> hasProfile() async {
    final db = await database;
    final result = await db.query('user_profile', where: 'id = 1');
    return result.isNotEmpty;
  }

  Future<UserProfile?> getProfile() async {
    final db = await database;
    final maps = await db.query('user_profile', where: 'id = 1');
    if (maps.isEmpty) return null;
    return UserProfile.fromMap(maps.first);
  }

  Future<void> saveProfile(UserProfile profile) async {
    final db = await database;
    await db.insert(
      'user_profile',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---- ECG Records ----

  Future<int> insertRecord(ECGRecord record) async {
    final db = await database;
    return await db.insert('ecg_records', record.toMap());
  }

  Future<List<ECGRecord>> getAllRecords() async {
    final db = await database;
    final maps = await db.query('ecg_records', orderBy: 'timestamp DESC');
    return maps.map((m) => ECGRecord.fromMap(m)).toList();
  }

  Future<ECGRecord?> getRecordById(int id) async {
    final db = await database;
    final maps = await db.query('ecg_records', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return ECGRecord.fromMap(maps.first);
  }

  Future<void> updateDoctorNotes(int id, String notes) async {
    final db = await database;
    await db.update(
      'ecg_records',
      {'doctor_notes': notes},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteRecord(int id) async {
    final db = await database;
    await db.delete('ecg_records', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, int>> getStats() async {
    final db = await database;
    final total = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM ecg_records')) ?? 0;
    final normal = Sqflite.firstIntValue(await db.rawQuery(
        "SELECT COUNT(*) FROM ecg_records WHERE severity = 'normal'")) ?? 0;
    final warning = Sqflite.firstIntValue(await db.rawQuery(
        "SELECT COUNT(*) FROM ecg_records WHERE severity = 'warning'")) ?? 0;
    final critical = Sqflite.firstIntValue(await db.rawQuery(
        "SELECT COUNT(*) FROM ecg_records WHERE severity = 'critical'")) ?? 0;
    return {
      'total': total,
      'normal': normal,
      'warning': warning,
      'critical': critical,
    };
  }

  Future<List<ECGRecord>> searchRecords(String query) async {
    final db = await database;
    final maps = await db.query(
      'ecg_records',
      where: 'interpretation LIKE ? OR patient_name LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'timestamp DESC',
    );
    return maps.map((m) => ECGRecord.fromMap(m)).toList();
  }

  Future<List<ECGRecord>> getRecordsInRange(DateTime start, DateTime end) async {
    final db = await database;
    final maps = await db.query(
      'ecg_records',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => ECGRecord.fromMap(m)).toList();
  }
}
