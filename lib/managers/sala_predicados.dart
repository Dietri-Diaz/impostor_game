// lib/managers/sala_predicados.dart
import '../services/sala_gateway.dart';

/// Solo cuentan los jugadores vivos (no eliminados) y conectados.
List<JugadorSala> activos(List<JugadorSala> jugadores) =>
    jugadores.where((j) => j.conectado && !j.eliminado).toList();

bool puedeIniciar(List<JugadorSala> jugadores) =>
    activos(jugadores).length >= 3;

/// True cuando todos los vivos+conectados ya emitieron su voto.
bool todosVotaron(List<JugadorSala> jugadores, Map<String, String> votos) {
  final pendientes = activos(jugadores).where((j) => !votos.containsKey(j.uid));
  return activos(jugadores).isNotEmpty && pendientes.isEmpty;
}
