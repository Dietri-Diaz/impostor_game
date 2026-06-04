// lib/models/ronda.dart

import 'jugador.dart';

class Ronda {
  final int numero;
  final List<Jugador> jugadoresVivos;
  Map<String, String> votos; // jugadorId: votadoId
  Map<String, int>? conteoVotos; // jugadorId: cantidad de votos
  Jugador? jugadorEliminado;
  bool huboEmpate;
  List<String>? jugadoresEmpatados;
  /// Jugador designado para empezar a dar pistas/describir esta ronda.
  /// Se elige con sesgo a que el impostor hable tarde (ver PartidaManager).
  Jugador? jugadorInicial;
  DateTime inicio;
  DateTime? fin;

  Ronda({
    required this.numero,
    required this.jugadoresVivos,
    Map<String, String>? votos,
    this.conteoVotos,
    this.jugadorEliminado,
    this.huboEmpate = false,
    this.jugadoresEmpatados,
    this.jugadorInicial,
    DateTime? inicio,
    this.fin,
  })  : votos = votos ?? {},
        inicio = inicio ?? DateTime.now();

  bool get estaCompleta => fin != null;

  void finalizarRonda() {
    fin = DateTime.now();
  }

  Map<String, dynamic> toJson() {
    return {
      'numero': numero,
      'jugadoresVivos': jugadoresVivos.map((j) => j.toJson()).toList(),
      'votos': votos,
      'conteoVotos': conteoVotos,
      'jugadorEliminado': jugadorEliminado?.toJson(),
      'huboEmpate': huboEmpate,
      'jugadoresEmpatados': jugadoresEmpatados,
      'jugadorInicial': jugadorInicial?.toJson(),
      'inicio': inicio.toIso8601String(),
      'fin': fin?.toIso8601String(),
    };
  }

  factory Ronda.fromJson(Map<String, dynamic> json) {
    Map<String, String> parseVotos(Object? raw) {
      final m = (raw as Map?) ?? const {};
      return {for (final e in m.entries) e.key as String: e.value as String};
    }

    Map<String, int>? parseConteo(Object? raw) {
      if (raw == null) return null;
      final m = (raw as Map);
      return {for (final e in m.entries) e.key as String: e.value as int};
    }

    final elimRaw = json['jugadorEliminado'];
    final iniRaw = json['jugadorInicial'];
    return Ronda(
      numero: json['numero'] as int,
      jugadoresVivos: [
        for (final j in (json['jugadoresVivos'] as List? ?? const []))
          Jugador.fromJson((j as Map).cast<String, dynamic>()),
      ],
      votos: parseVotos(json['votos']),
      conteoVotos: parseConteo(json['conteoVotos']),
      jugadorEliminado: elimRaw == null
          ? null
          : Jugador.fromJson((elimRaw as Map).cast<String, dynamic>()),
      huboEmpate: (json['huboEmpate'] as bool?) ?? false,
      jugadoresEmpatados:
          (json['jugadoresEmpatados'] as List?)?.cast<String>(),
      jugadorInicial: iniRaw == null
          ? null
          : Jugador.fromJson((iniRaw as Map).cast<String, dynamic>()),
      inicio: DateTime.parse(json['inicio'] as String),
      fin: (json['fin'] as String?) == null
          ? null
          : DateTime.parse(json['fin'] as String),
    );
  }
}