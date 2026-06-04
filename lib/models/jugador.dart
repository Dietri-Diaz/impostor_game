// lib/models/jugador.dart

import '../core/enums.dart';

class Jugador {
  final String id;
  final String nombre;
  final int numero;
  final bool esImpostor;
  bool haVisto;
  EstadoJugador estado;
  int? rondaEliminado;

  Jugador({
    required this.id,
    required this.nombre,
    required this.numero,
    required this.esImpostor,
    this.haVisto = false,
    this.estado = EstadoJugador.vivo,
    this.rondaEliminado,
  });

  bool get estaVivo => estado == EstadoJugador.vivo;

  void eliminar(int numeroRonda) {
    estado = EstadoJugador.eliminado;
    rondaEliminado = numeroRonda;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'numero': numero,
      'esImpostor': esImpostor,
      'haVisto': haVisto,
      'estado': estado.name,
      'rondaEliminado': rondaEliminado,
    };
  }

  factory Jugador.fromJson(Map<String, dynamic> json) {
    return Jugador(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      numero: json['numero'] as int,
      esImpostor: json['esImpostor'] as bool,
      haVisto: (json['haVisto'] as bool?) ?? false,
      estado: EstadoJugador.values.firstWhere(
        (e) => e.name == json['estado'],
        orElse: () => EstadoJugador.vivo,
      ),
      rondaEliminado: json['rondaEliminado'] as int?,
    );
  }
}