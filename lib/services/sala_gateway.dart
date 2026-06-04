// lib/services/sala_gateway.dart

/// Fases de una sala online. El nombre del enum se persiste en RTDB.
enum EstadoSala {
  lobby,
  revelando,
  discusion,
  votando,
  resultado,
  finalizada,
  abandonada,
}

EstadoSala estadoSalaFromName(String? name) =>
    EstadoSala.values.firstWhere((e) => e.name == name,
        orElse: () => EstadoSala.lobby);

/// Un jugador tal como vive en /salas/{codigo}/jugadores/{uid}.
class JugadorSala {
  const JugadorSala({
    required this.uid,
    required this.nombre,
    required this.numero,
    required this.conectado,
    required this.listo,
    required this.eliminado,
  });

  final String uid;
  final String nombre;
  final int numero;
  final bool conectado;
  final bool listo;
  final bool eliminado;

  Map<String, Object?> toMap() => {
        'nombre': nombre,
        'numero': numero,
        'conectado': conectado,
        'listo': listo,
        'eliminado': eliminado,
      };

  factory JugadorSala.fromMap(String uid, Map<String, dynamic> m) => JugadorSala(
        uid: uid,
        nombre: (m['nombre'] as String?) ?? '',
        numero: (m['numero'] as int?) ?? 0,
        conectado: (m['conectado'] as bool?) ?? false,
        listo: (m['listo'] as bool?) ?? false,
        eliminado: (m['eliminado'] as bool?) ?? false,
      );

  JugadorSala copyWith({bool? conectado, bool? listo, bool? eliminado, String? nombre}) =>
      JugadorSala(
        uid: uid,
        nombre: nombre ?? this.nombre,
        numero: numero,
        conectado: conectado ?? this.conectado,
        listo: listo ?? this.listo,
        eliminado: eliminado ?? this.eliminado,
      );
}

/// Rol privado de un jugador: vive solo en /salas/{codigo}/privado/{uid}.
class RolPrivado {
  const RolPrivado({required this.esImpostor, required this.personajeVisto});
  final bool esImpostor;
  final String? personajeVisto; // null si es impostor

  Map<String, Object?> toMap() =>
      {'esImpostor': esImpostor, 'personajeVisto': personajeVisto};

  factory RolPrivado.fromMap(Map<String, dynamic> m) => RolPrivado(
        esImpostor: (m['esImpostor'] as bool?) ?? false,
        personajeVisto: m['personajeVisto'] as String?,
      );
}
