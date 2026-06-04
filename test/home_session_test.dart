// test/home_session_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:impostor_game/services/preferences_service.dart';
import 'package:impostor_game/screens/home_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets(
      'Tocar "Jugar ahora" y regresar NO borra la sesión guardada',
      (tester) async {
    const sessionJson =
        '{"tematica":"Marvel","nombresJugadores":["A","B","C"],'
        '"configuracion":{"tiempoDiscusion":120,"eliminarEnEmpate":false,'
        '"numeroImpostores":1},"historialRondas":[],"puntuacion":{}}';
    SharedPreferences.setMockInitialValues({
      'session.active': sessionJson,
      'onboarding.done': true,
    });
    final prefs = PreferencesService(await SharedPreferences.getInstance());

    await tester.pumpWidget(MaterialApp(
      home: Provider<PreferencesService>.value(
        value: prefs,
        child: const HomeScreen(),
      ),
    ));
    // Use pump with finite duration instead of pumpAndSettle to avoid
    // timing out on the repeating pulse animation in HomeScreen.
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.text('Jugar ahora'));
    // Pump enough to let the async onPressed run (clearActiveSession + navigation).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // La sesión guardada debe seguir intacta tras iniciar la configuración.
    expect(prefs.activeSessionJson, isNotNull);
    expect(prefs.activeSessionJson, contains('Marvel'));
  });
}
