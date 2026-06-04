// lib/services/audio_service.dart

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Servicio de audio. Los assets reales se cablean cuando estén disponibles
/// (las llamadas a `_player.play(...)` están comentadas hasta entonces).
class AudioService {
  AudioService._();

  static final AudioPlayer _player = AudioPlayer();
  static bool _soundEnabled = true;

  static void toggleSound() => _soundEnabled = !_soundEnabled;
  static bool get isSoundEnabled => _soundEnabled;

  static Future<void> _play(String label, String? assetPath) async {
    if (!_soundEnabled) return;
    try {
      if (assetPath != null) {
        await _player.play(AssetSource(assetPath));
      }
      if (kDebugMode) debugPrint('🔊 $label');
    } catch (e) {
      if (kDebugMode) debugPrint('Error reproduciendo $label: $e');
    }
  }

  static Future<void> playClick() => _play('click', null);
  static Future<void> playReveal() => _play('reveal', null);
  static Future<void> playImpostor() => _play('impostor', null);
  static Future<void> playVictory() => _play('victory', null);

  static Future<void> dispose() => _player.dispose();
}
