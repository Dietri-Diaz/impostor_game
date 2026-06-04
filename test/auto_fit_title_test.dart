// test/auto_fit_title_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impostor_game/widgets/auto_fit_title.dart';

void main() {
  testWidgets('AutoFitTitle no desborda en ancho muy estrecho', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 80, // muy angosto
          child: AutoFitTitle('IMPOSTOR', style: TextStyle(fontSize: 80)),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('IMPOSTOR'), findsOneWidget);
  });
}
