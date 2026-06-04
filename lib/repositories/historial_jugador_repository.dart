// lib/repositories/historial_jugador_repository.dart

import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../database/database_service.dart';
import '../models/historial_jugador.dart';

class HistorialJugadorRepository {
  HistorialJugadorRepository({DatabaseService? db})
      : _db = db ?? DatabaseService.instance;

  final DatabaseService _db;

  /// Guarda los nombres en una sola transacción usando UPSERT.
  /// Antes era N round-trips a SQLite y vulnerable a condiciones de carrera.
  Future<void> guardarNombres(List<String> nombres) async {
    if (nombres.isEmpty) return;
    try {
      final ahora = DateTime.now().toIso8601String();
      await _db.runInTransaction((txn) async {
        for (final raw in nombres) {
          final nombre = raw.trim();
          if (nombre.isEmpty) continue;
          await txn.rawInsert(
            'INSERT INTO historial_jugadores (nombre, ultimo_uso, veces_usado) '
            'VALUES (?, ?, 1) '
            'ON CONFLICT(nombre) DO UPDATE SET '
            'veces_usado = veces_usado + 1, ultimo_uso = excluded.ultimo_uso',
            [nombre, ahora],
          );
        }
      });
    } catch (e, st) {
      debugPrint('[HistorialRepo] guardarNombres fallo: $e\n$st');
      rethrow;
    }
  }

  Future<List<HistorialJugador>> obtenerHistorial() async {
    try {
      final db = await _db.database;
      final data = await db.query(
        'historial_jugadores',
        orderBy: 'veces_usado DESC, ultimo_uso DESC',
        limit: GameConstants.recentNamesLimit,
      );
      return data.map(HistorialJugador.fromJson).toList();
    } catch (e, st) {
      debugPrint('[HistorialRepo] obtenerHistorial fallo: $e\n$st');
      rethrow;
    }
  }

  Future<List<String>> buscarNombres(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final db = await _db.database;
      final data = await db.query(
        'historial_jugadores',
        columns: ['nombre'],
        where: 'nombre LIKE ?',
        whereArgs: ['%$trimmed%'],
        orderBy: 'veces_usado DESC',
        limit: GameConstants.nameSuggestionsLimit,
      );
      return data.map((json) => json['nombre']! as String).toList();
    } catch (e, st) {
      debugPrint('[HistorialRepo] buscarNombres fallo: $e\n$st');
      // Las sugerencias son opcionales: devolvemos vacío en vez de propagar.
      return const [];
    }
  }

  Future<void> eliminarNombre(String nombre) async {
    try {
      final db = await _db.database;
      await db.delete(
        'historial_jugadores',
        where: 'nombre = ?',
        whereArgs: [nombre.trim()],
      );
    } catch (e, st) {
      debugPrint('[HistorialRepo] eliminarNombre fallo: $e\n$st');
      rethrow;
    }
  }
}
