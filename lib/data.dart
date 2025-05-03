import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class Song {
  final String id;
  final String title;
  final String description;
  final String artist;
  final String? audioPath;
  final String? imagePath;

  Song({
    required this.artist,
    required this.id,
    required this.title,
    required this.description,
    this.audioPath,
    this.imagePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'audioPath': audioPath,
      'imagePath': imagePath,
    };
  }

  factory Song.fromMap(Map<String, dynamic> map) {
    return Song(
      artist: 'me',
      id: map['id'],
      title: map['title'],
      description: map['description'],
      audioPath: map['audioPath'],
      imagePath: map['imagePath'],
    );
  }
}

// Dummy data


class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('songs.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE favorites(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        audioPath TEXT,
        imagePath TEXT
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE favorites ADD COLUMN audioPath TEXT');
      await db.execute('ALTER TABLE favorites ADD COLUMN imagePath TEXT');
    }
  }

  Future<void> insertFavorite(Song song) async {
    final db = await database;
    await db.insert(
      'favorites',
      song.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteFavorite(String id) async {
    final db = await database;
    await db.delete(
      'favorites',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<bool> isFavorite(String id) async {
    final db = await database;
    final result = await db.query(
      'favorites',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty;
  }

  Future<List<Song>> getFavorites() async {
    final db = await database;
    final maps = await db.query('favorites');
    return List.generate(maps.length, (i) {
      return Song.fromMap(maps[i]);
    });
  }
}