import '/kernel/models/face.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _db;

  Future<void> init() async {
    if (_db != null) return;
    final path = join(await getDatabasesPath(), 'faces_v2.db');
    _db = await openDatabase(
      path,
      version: 2, // Version incrémentée
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE faces (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            matricule TEXT,
            name TEXT,
            embedding TEXT,
            image_path TEXT
          )
        ''');
        await db.execute('CREATE INDEX idx_matricule ON faces (matricule)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE faces ADD COLUMN name TEXT');
        }
      },
    );
  }

  Future<void> insertFace(FacePicture face) async {
    await init();
    await _db!.insert(
      'faces',
      face.toMap(),
    );
  }

  Future<List<FacePicture>> getAllFaces() async {
    await init();
    final List<Map<String, dynamic>> maps = await _db!.query('faces');
    return maps.map(FacePicture.fromMap).toList();
  }

  Future<void> deleteFace(String matricule) async {
    await init();
    await _db!.delete(
      'faces',
      where: 'matricule = ?',
      whereArgs: [matricule],
    );
  }

  Future<void> deleteAll() async {
    await init();
    await _db!.delete('faces');
  }
}
