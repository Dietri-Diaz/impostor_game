// test/sesion_juego_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:impostor_game/managers/partida_manager.dart';
import 'package:impostor_game/models/configuracion_partida.dart';
import 'package:impostor_game/models/sesion_juego.dart';

SesionJuego _newSesion() => SesionJuego(
      tematica: 'Marvel',
      nombresJugadores: const ['Ana', 'Bob', 'Carlos', 'Diana'],
      configuracion: ConfiguracionPartida(),
    );

void main() {
  group('SesionJuego ChangeNotifier', () {
    test('cambiar tematica notifica a los listeners', () {
      final s = _newSesion();
      var calls = 0;
      s.addListener(() => calls++);
      s.tematica = 'Naruto';
      expect(calls, 1);
      expect(s.tematica, 'Naruto');
    });

    test('asignar la misma tematica no notifica', () {
      final s = _newSesion();
      var calls = 0;
      s.addListener(() => calls++);
      s.tematica = 'Marvel';
      expect(calls, 0);
    });

    test('cambiar nombresJugadores notifica e inicializa puntuacion', () {
      final s = _newSesion();
      var calls = 0;
      s.addListener(() => calls++);
      s.nombresJugadores = ['Eva', 'Fer', 'Gus'];
      expect(calls, 1);
      expect(s.nombresJugadores, ['Eva', 'Fer', 'Gus']);
      expect(s.puntuacion.containsKey('Eva'), isTrue);
    });

    test('nombresJugadores expone lista inmutable', () {
      final s = _newSesion();
      expect(
        () => s.nombresJugadores.add('X'),
        throwsUnsupportedError,
      );
    });

    test('inicializarPuntuacion crea entradas en 0', () {
      final s = _newSesion()..inicializarPuntuacion();
      expect(s.puntuacion['Ana'], 0);
      expect(s.puntuacion.length, 4);
    });

    test('registrarResultado actualiza puntuacion y notifica', () {
      final s = _newSesion()..inicializarPuntuacion();
      final manager = PartidaManager();
      final partida = manager.crearPartida(
        tematica: 'Marvel',
        personajeSecreto: 'Spider-Man',
        nombresJugadores: s.nombresJugadores,
        configuracion: s.configuracion,
      );
      // Forzamos victoria del impostor con final de juego válido
      manager.iniciarRonda();
      // Eliminamos los 2 no impostores para que gane el impostor
      final noImps = partida.jugadores.where((j) => !j.esImpostor).toList();
      manager.eliminarJugador(noImps[0].id);
      manager.iniciarRonda();
      manager.eliminarJugador(noImps[1].id);
      manager.verificarFinDeJuego();

      var calls = 0;
      s.addListener(() => calls++);
      s.registrarResultado(partida: partida, numeroRonda: 1);
      expect(calls, 1);
      expect(s.rondasJugadas, 1);

      // El impostor gana 3 puntos cuando sobrevive
      final impostor = partida.impostor.nombre;
      expect(s.puntuacion[impostor], 3);
    });

    test('rankingOrdenado devuelve por puntos descendente', () {
      final s = _newSesion()
        ..inicializarPuntuacion()
        ..puntuacion['Ana'] = 5
        ..puntuacion['Bob'] = 10
        ..puntuacion['Carlos'] = 2
        ..puntuacion['Diana'] = 8;

      final ranking = s.rankingOrdenado;
      expect(ranking.map((e) => e.key).toList(),
          ['Bob', 'Diana', 'Ana', 'Carlos']);
    });
  });
}
