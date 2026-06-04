import 'package:flutter_test/flutter_test.dart';
import 'package:impostor_game/models/ronda.dart';
import 'package:impostor_game/models/partida.dart';
import 'package:impostor_game/models/jugador.dart';
import 'package:impostor_game/models/configuracion_partida.dart';
import 'package:impostor_game/core/enums.dart';

void main() {
  test('Ronda round-trips votos/conteo/jugadorInicial/eliminado/fin', () {
    final a = Jugador(id: 'u1', nombre: 'Ana', numero: 1, esImpostor: true);
    final b = Jugador(id: 'u2', nombre: 'Beto', numero: 2, esImpostor: false);
    final ronda = Ronda(
      numero: 2,
      jugadoresVivos: [a, b],
      votos: {'u1': 'u2', 'u2': 'u1'},
      conteoVotos: {'u1': 1, 'u2': 1},
      jugadorEliminado: b,
      huboEmpate: true,
      jugadoresEmpatados: ['u1', 'u2'],
      jugadorInicial: a,
      inicio: DateTime.parse('2026-06-03T10:00:00.000'),
      fin: DateTime.parse('2026-06-03T10:05:00.000'),
    );

    final r = Ronda.fromJson(ronda.toJson());

    expect(r.numero, 2);
    expect(r.jugadoresVivos.length, 2);
    expect(r.votos, {'u1': 'u2', 'u2': 'u1'});
    expect(r.conteoVotos, {'u1': 1, 'u2': 1});
    expect(r.jugadorEliminado?.id, 'u2');
    expect(r.huboEmpate, true);
    expect(r.jugadoresEmpatados, ['u1', 'u2']);
    expect(r.jugadorInicial?.id, 'u1');
    expect(r.fin, isNotNull);
  });

  test('Ronda round-trips con campos nulos (sin eliminado/fin/conteo)', () {
    final ronda = Ronda(
      numero: 1,
      jugadoresVivos: const [],
      inicio: DateTime.parse('2026-06-03T10:00:00.000'),
    );
    final r = Ronda.fromJson(ronda.toJson());
    expect(r.numero, 1);
    expect(r.conteoVotos, isNull);
    expect(r.jugadorEliminado, isNull);
    expect(r.jugadorInicial, isNull);
    expect(r.fin, isNull);
    expect(r.votos, isEmpty);
  });

  test('Partida round-trips ganador no nulo y rondas no vacías', () {
    final a = Jugador(id: 'u1', nombre: 'Ana', numero: 1, esImpostor: true);
    final partida = Partida(
      id: 'p1',
      tematica: 'Animales',
      personajeSecreto: 'León',
      configuracion: ConfiguracionPartida(),
      jugadores: [a],
      rondas: [
        Ronda(
          numero: 1,
          jugadoresVivos: [a],
          inicio: DateTime.parse('2026-06-03T10:00:00.000'),
        ),
      ],
      rondaActual: 2,
      finalizada: true,
      ganador: TipoGanador.impostor,
    );

    final p = Partida.fromJson(partida.toJson());

    expect(p.rondaActual, 2);
    expect(p.finalizada, true);
    expect(p.ganador, TipoGanador.impostor);
    expect(p.rondas.length, 1);
    expect(p.rondas.first.numero, 1);
  });
}
