// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_theme.dart';
import 'screens/home_screen.dart';
import 'services/firebase_service.dart';
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
  final firebase = await FirebaseService.tryInit(); // null si Firebase no está listo

  runApp(
    MultiProvider(
      providers: [
        Provider<PreferencesService>.value(value: prefs),
        Provider<FirebaseService?>.value(value: firebase),
      ],
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
