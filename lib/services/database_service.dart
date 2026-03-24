import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/ecg_record.dart';

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
      version: 1,
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
            doctor_notes TEXT
          )
        ''');
      },
    );
  }

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
      where: 'patient_name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'timestamp DESC',
    );
    return maps.map((m) => ECGRecord.fromMap(m)).toList();
  }
}
