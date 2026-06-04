// lib/database/database_service.dart

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Acceso centralizado a SQLite.
///
/// Versión 3 añade índices sobre columnas que se filtran/ordenan con
/// frecuencia (`tematicas.nombre`, `historial_jugadores.nombre`,
/// `historial_jugadores.veces_usado`, `partidas.fecha`). Sin ellos la app
/// hacía full-table-scans innecesarios.
class DatabaseService {
  DatabaseService._init();

  static const int _schemaVersion = 3;

  static Database? _database;
  static final DatabaseService instance = DatabaseService._init();

  Future<Database> get database async {
    return _database ??= await _initDB('impostor_game.db');
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return openDatabase(
      path,
      version: _schemaVersion,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.transaction((txn) async {
      await txn.execute('''
        CREATE TABLE tematicas (
          id TEXT PRIMARY KEY,
          nombre TEXT NOT NULL,
          personajes TEXT NOT NULL,
          fecha_creacion TEXT NOT NULL,
          es_personalizada INTEGER NOT NULL
        )
      ''');

      await txn.execute('''
        CREATE TABLE configuraciones (
          id INTEGER PRIMARY KEY,
          tiempo_discusion INTEGER NOT NULL,
          eliminar_en_empate INTEGER NOT NULL
        )
      ''');

      await txn.execute('''
        CREATE TABLE partidas (
          id TEXT PRIMARY KEY,
          tematica TEXT NOT NULL,
          personaje_secreto TEXT NOT NULL,
          ganador TEXT NOT NULL,
          fecha TEXT NOT NULL,
          numero_jugadores INTEGER NOT NULL,
          numero_rondas INTEGER NOT NULL
        )
      ''');

      await txn.execute('''
        CREATE TABLE historial_jugadores (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre TEXT NOT NULL UNIQUE,
          ultimo_uso TEXT NOT NULL,
          veces_usado INTEGER NOT NULL DEFAULT 1
        )
      ''');

      await _createIndexes(txn);

      await txn.insert('configuraciones', {
        'id': 1,
        'tiempo_discusion': 120,
        'eliminar_en_empate': 0,
      });
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS historial_jugadores (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre TEXT NOT NULL UNIQUE,
          ultimo_uso TEXT NOT NULL,
          veces_usado INTEGER NOT NULL DEFAULT 1
        )
      ''');
    }
    if (oldVersion < 3) {
      await _createIndexes(db);
    }
  }

  Future<void> _createIndexes(DatabaseExecutor db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tematicas_nombre ON tematicas(nombre)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_historial_nombre '
      'ON historial_jugadores(nombre)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_historial_uso '
      'ON historial_jugadores(veces_usado DESC, ultimo_uso DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_partidas_fecha ON partidas(fecha DESC)',
    );
  }

  // ---------- CRUD Temáticas ----------

  Future<int> insertTematica(Map<String, dynamic> tematica) async {
    final db = await database;
    return db.insert('tematicas', tematica);
  }

  Future<List<Map<String, dynamic>>> getTematicas() async {
    final db = await database;
    return db.query('tematicas', orderBy: 'fecha_creacion DESC');
  }

  Future<int> updateTematica(String id, Map<String, dynamic> tematica) async {
    final db = await database;
    return db.update(
      'tematicas',
      tematica,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteTematica(String id) async {
    final db = await database;
    return db.delete(
      'tematicas',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------- Configuración ----------

  Future<Map<String, dynamic>?> getConfiguracion() async {
    final db = await database;
    final result = await db.query('configuraciones', where: 'id = 1');
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> updateConfiguracion(Map<String, dynamic> config) async {
    final db = await database;
    return db.update(
      'configuraciones',
      config,
      where: 'id = 1',
    );
  }

  // ---------- Historial de partidas ----------

  Future<int> insertPartida(Map<String, dynamic> partida) async {
    final db = await database;
    return db.insert('partidas', partida);
  }

  Future<List<Map<String, dynamic>>> getPartidas() async {
    final db = await database;
    return db.query('partidas', orderBy: 'fecha DESC');
  }

  // ---------- Utilidad transaccional para repos ----------

  /// Permite a los repositorios componer múltiples operaciones atómicamente.
  Future<T> runInTransaction<T>(
    Future<T> Function(Transaction txn) action,
  ) async {
    final db = await database;
    return db.transaction(action);
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
