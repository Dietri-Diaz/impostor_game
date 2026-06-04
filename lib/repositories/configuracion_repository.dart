// lib/repositories/configuracion_repository.dart

import 'package:flutter/foundation.dart';

import '../database/database_service.dart';
import '../models/configuracion_partida.dart';

class ConfiguracionRepository {
  ConfiguracionRepository({DatabaseService? db})
      : _db = db ?? DatabaseService.instance;

  final DatabaseService _db;

  Future<ConfiguracionPartida> obtenerConfiguracion() async {
    try {
      final data = await _db.getConfiguracion();
      if (data == null) {
        return ConfiguracionPartida(); // Default
      }
      return ConfiguracionPartida.fromJson(data);
    } catch (e, st) {
      debugPrint('[ConfigRepo] obtenerConfiguracion fallo: $e\n$st');
      rethrow;
    }
  }

  Future<void> guardarConfiguracion(ConfiguracionPartida config) async {
    try {
      await _db.updateConfiguracion({
        'tiempo_discusion': config.segundosDiscusion,
        'eliminar_en_empate': config.eliminarEnEmpate ? 1 : 0,
      });
    } catch (e, st) {
      debugPrint('[ConfigRepo] guardarConfiguracion fallo: $e\n$st');
      rethrow;
    }
  }
}