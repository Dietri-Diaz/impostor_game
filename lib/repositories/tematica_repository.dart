// lib/repositories/tematica_repository.dart

import 'package:flutter/foundation.dart';

import '../database/database_service.dart';
import '../models/tematica_personalizada.dart';

class TematicaRepository {
  TematicaRepository({DatabaseService? db})
      : _db = db ?? DatabaseService.instance;

  final DatabaseService _db;

  Future<void> guardarTematica(TematicaPersonalizada tematica) async {
    try {
      await _db.insertTematica(tematica.toJson());
    } catch (e, st) {
      debugPrint('[TematicaRepo] guardarTematica fallo: $e\n$st');
      rethrow;
    }
  }

  Future<List<TematicaPersonalizada>> obtenerTematicas() async {
    try {
      final data = await _db.getTematicas();
      return data.map((json) => TematicaPersonalizada.fromJson(json)).toList();
    } catch (e, st) {
      debugPrint('[TematicaRepo] obtenerTematicas fallo: $e\n$st');
      rethrow;
    }
  }

  Future<void> actualizarTematica(TematicaPersonalizada tematica) async {
    try {
      await _db.updateTematica(tematica.id, tematica.toJson());
    } catch (e, st) {
      debugPrint('[TematicaRepo] actualizarTematica fallo: $e\n$st');
      rethrow;
    }
  }

  Future<void> eliminarTematica(String id) async {
    try {
      await _db.deleteTematica(id);
    } catch (e, st) {
      debugPrint('[TematicaRepo] eliminarTematica fallo: $e\n$st');
      rethrow;
    }
  }
}