// lib/services/firebase_service.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

/// Inicializa Firebase y mantiene una sesión anónima. El UID anónimo es
/// estable por instalación, lo que permite reconexión. Si Firebase no está
/// configurado (sin google-services.json, sin red, o auth anónima
/// deshabilitada), [tryInit] devuelve null y la app sigue funcionando en
/// modo local — el modo online simplemente queda deshabilitado.
class FirebaseService {
  FirebaseService._(this.db, this.uid);

  final FirebaseDatabase db;
  final String uid;

  /// Llamar una vez en main(). Nunca lanza: devuelve null si falla.
  static Future<FirebaseService?> tryInit() async {
    try {
      await Firebase.initializeApp();
      final cred = await FirebaseAuth.instance.signInAnonymously();
      final uid = cred.user!.uid;
      return FirebaseService._(FirebaseDatabase.instance, uid);
    } catch (e) {
      debugPrint('FirebaseService.tryInit falló (modo online deshabilitado): $e');
      return null;
    }
  }
}
