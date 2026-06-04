// lib/models/historial_jugador.dart

class HistorialJugador {
  final int? id;
  final String nombre;
  final DateTime ultimoUso;
  final int vecesUsado;

  HistorialJugador({
    this.id,
    required this.nombre,
    DateTime? ultimoUso,
    this.vecesUsado = 1,
  }) : ultimoUso = ultimoUso ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'ultimo_uso': ultimoUso.toIso8601String(),
      'veces_usado': vecesUsado,
    };
  }

  factory HistorialJugador.fromJson(Map<String, dynamic> json) {
    return HistorialJugador(
      id: json['id'] as int?,
      nombre: json['nombre'] as String,
      ultimoUso: DateTime.parse(json['ultimo_uso'] as String),
      vecesUsado: (json['veces_usado'] as int?) ?? 1,
    );
  }
}
