// test/widget_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:impostor_game/main.dart';
import 'package:impostor_game/screens/home_screen.dart';
import 'package:impostor_game/services/preferences_service.dart';

/// Construye la app con un [PreferencesService] real sobre SharedPreferences
/// mockeado, igual que `main()` provee el servicio por encima de [ImpostorGame].
/// `onboarding.done: true` evita que el Home navegue al onboarding en el
/// primer frame (lo que ocultaría los elementos del Home).
Future<Widget> _appBajoPrueba() async {
  SharedPreferences.setMockInitialValues({'onboarding.done': true});
  final prefs = PreferencesService(await SharedPreferences.getInstance());
  return Provider<PreferencesService>.value(
    value: prefs,
    child: const ImpostorGame(),
  );
}

void main() {
  testWidgets('App should load without errors', (WidgetTester tester) async {
    await tester.pumpWidget(await _appBajoPrueba());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('HomeScreen muestra elementos principales',
      (WidgetTester tester) async {
    await tester.pumpWidget(await _appBajoPrueba());
    // Las animaciones de entrada pueden tardar — bombeamos un poco.
    await tester.pump(const Duration(milliseconds: 100));
    // Debe existir al menos un Scaffold (el de la HomeScreen).
    expect(find.byType(Scaffold), findsWidgets);
    // El wordmark y el botón principal del rediseño Minimal Bold.
    expect(find.text('IMPOSTOR'), findsOneWidget);
    expect(find.text('Jugar ahora'), findsOneWidget);
  });
}
