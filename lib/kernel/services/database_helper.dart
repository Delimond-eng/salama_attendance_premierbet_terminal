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
    final path = join(await getDatabasesPath(), 'faces_v2.db'); // Nouvelle version pour multi-templates
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE faces (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            matricule TEXT,
            embedding TEXT,
            image_path TEXT
          )
        ''');
        await db.execute('CREATE INDEX idx_matricule ON faces (matricule)');
      },
    );
  }

  Future<void> insertFace(FacePicture face) async {
    await init();
    // On insère sans écraser pour garder les multi-templates
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
