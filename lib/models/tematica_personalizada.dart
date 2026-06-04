// lib/models/tematica_personalizada.dart

import 'package:uuid/uuid.dart';

class TematicaPersonalizada {
  final String id;
  final String nombre;
  final List<String> personajes;
  final DateTime fechaCreacion;
  final bool esPersonalizada;

  TematicaPersonalizada({
    String? id,
    required this.nombre,
    required this.personajes,
    DateTime? fechaCreacion,
    this.esPersonalizada = true,
  })  : id = id ?? const Uuid().v4(),
        fechaCreacion = fechaCreacion ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'personajes': personajes.join(','),
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'es_personalizada': esPersonalizada ? 1 : 0,
    };
  }

  factory TematicaPersonalizada.fromJson(Map<String, dynamic> json) {
    return TematicaPersonalizada(
      id: json['id'] as String?,
      nombre: json['nombre'] as String,
      personajes: (json['personajes'] as String).split(','),
      fechaCreacion: DateTime.parse(json['fecha_creacion'] as String),
      esPersonalizada: json['es_personalizada'] == 1,
    );
  }
}