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
}