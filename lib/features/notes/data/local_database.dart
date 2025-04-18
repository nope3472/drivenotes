import 'package:drivenotes/features/notes/domain/models/note_model.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._internal();
  static const _databaseName = 'drivenotes.db';
  static const _databaseVersion = 1;
  static const _tableName = 'notes';

  static Database? _database;

  factory LocalDatabase() {
    return instance;
  }

  LocalDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        isSynced INTEGER NOT NULL DEFAULT 0,
        driveId TEXT
      )
    ''');
  }

  Future<void> insertNote(NoteModel note) async {
    final db = await database;
    await db.insert(_tableName, {
      'id': note.id,
      'title': note.title,
      'content': note.content,
      'createdAt': note.createdAt.toIso8601String(),
      'updatedAt': note.updatedAt.toIso8601String(),
      'isSynced': note.isSynced ? 1 : 0,
      'driveId': note.fileId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<NoteModel>> getUnsyncedNotes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'isSynced = ?',
      whereArgs: [0],
    );

    return List.generate(maps.length, (i) {
      return NoteModel(
        id: maps[i]['id'],
        title: maps[i]['title'],
        content: maps[i]['content'],
        createdAt: DateTime.parse(maps[i]['createdAt']),
        updatedAt: DateTime.parse(maps[i]['updatedAt']),
        fileId: maps[i]['driveId'],
        isSynced: maps[i]['isSynced'] == 1,
      );
    });
  }

  Future<void> markNoteAsSynced(String id, String driveId) async {
    final db = await database;
    await db.update(
      _tableName,
      {'isSynced': 1, 'driveId': driveId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<NoteModel>> getAllNotes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(_tableName);

    return List.generate(maps.length, (i) {
      return NoteModel(
        id: maps[i]['id'],
        title: maps[i]['title'],
        content: maps[i]['content'],
        createdAt: DateTime.parse(maps[i]['createdAt']),
        updatedAt: DateTime.parse(maps[i]['updatedAt']),
        fileId: maps[i]['driveId'],
        isSynced: maps[i]['isSynced'] == 1,
      );
    });
  }

  Future<void> deleteNote(String id) async {
    final db = await database;
    await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<NoteModel?> getNoteById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return NoteModel(
      id: maps[0]['id'],
      title: maps[0]['title'],
      content: maps[0]['content'],
      createdAt: DateTime.parse(maps[0]['createdAt']),
      updatedAt: DateTime.parse(maps[0]['updatedAt']),
      fileId: maps[0]['driveId'],
      isSynced: maps[0]['isSynced'] == 1,
    );
  }
}
