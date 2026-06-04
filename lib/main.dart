// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_theme.dart';
import 'screens/home_screen.dart';
import 'services/preferences_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  final sharedPrefs = await SharedPreferences.getInstance();
  final prefs = PreferencesService(sharedPrefs);

  runApp(
    Provider<PreferencesService>.value(
      value: prefs,
      child: const ImpostorGame(),
    ),
  );
}

class ImpostorGame extends StatelessWidget {
  const ImpostorGame({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Impostor Game',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
