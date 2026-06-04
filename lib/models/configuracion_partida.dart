// lib/models/configuracion_partida.dart

import '../core/enums.dart';

class ConfiguracionPartida {
  final TiempoDiscusion tiempoDiscusion;
  final bool eliminarEnEmpate;
  final int numeroImpostores;

  ConfiguracionPartida({
    this.tiempoDiscusion = TiempoDiscusion.dosMinutos,
    this.eliminarEnEmpate = false,
    this.numeroImpostores = 1,
  });

  int get segundosDiscusion => tiempoDiscusion.segundos;

  ConfiguracionPartida copyWith({
    TiempoDiscusion? tiempoDiscusion,
    bool? eliminarEnEmpate,
    int? numeroImpostores,
  }) {
    return ConfiguracionPartida(
      tiempoDiscusion: tiempoDiscusion ?? this.tiempoDiscusion,
      eliminarEnEmpate: eliminarEnEmpate ?? this.eliminarEnEmpate,
      numeroImpostores: numeroImpostores ?? this.numeroImpostores,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tiempoDiscusion': tiempoDiscusion.segundos,
      'eliminarEnEmpate': eliminarEnEmpate,
      'numeroImpostores': numeroImpostores,
    };
  }

  factory ConfiguracionPartida.fromJson(Map<String, dynamic> json) {
    return ConfiguracionPartida(
      tiempoDiscusion: TiempoDiscusion.values.firstWhere(
        (t) => t.segundos == json['tiempoDiscusion'],
        orElse: () => TiempoDiscusion.dosMinutos,
      ),
      eliminarEnEmpate: (json['eliminarEnEmpate'] as bool?) ?? false,
      numeroImpostores: (json['numeroImpostores'] as int?) ?? 1,
    );
  }
}