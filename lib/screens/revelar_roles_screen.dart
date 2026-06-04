// lib/screens/revelar_roles_screen.dart

import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/app_typography.dart';
import '../data/tematicas_data.dart';
import '../managers/partida_manager.dart';
import '../models/jugador.dart';
import '../models/partida.dart';
import '../models/sesion_juego.dart';
import '../services/audio_service.dart';
import '../services/preferences_service.dart';
import '../widgets/app_button.dart';
import '../widgets/auto_fit_title.dart';
import 'pasar_telefono_screen.dart';
import 'votacion_screen.dart';

class RevelarRolesScreen extends StatefulWidget {
  final Partida partida;
  final PartidaManager partidaManager;
  final SesionJuego? sesion;

  const RevelarRolesScreen({
    super.key,
    required this.partida,
    required this.partidaManager,
    this.sesion,
  });

  @override
  State<RevelarRolesScreen> createState() => _RevelarRolesScreenState();
}

class _RevelarRolesScreenState extends State<RevelarRolesScreen>
    with SingleTickerProviderStateMixin {
  Jugador? jugadorActual;
  bool mostrandoRol = false;
  bool _mostrandoPasarTelefono = false;
  int _jugadorPasarIndex = 0;

  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;
  late final String _emojiPersonaje;
  late final String? _imagenPersonaje;
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _flipAnimation = CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOutBack,
    );
    _confettiController =
        ConfettiController(duration: const Duration(milliseconds: 800));

    // Cache emoji + imagen once (avoids recomputing on every rebuild).
    final personajeData = _resolvePersonaje();
    _emojiPersonaje = personajeData.$1;
    _imagenPersonaje = personajeData.$2;

    _mostrarPasarTelefono(0);
  }

  @override
  void dispose() {
    _flipController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Navigation helpers
  // ---------------------------------------------------------------------------

  void _mostrarPasarTelefono(int index) {
    final jugadoresVivos = widget.partida.jugadoresVivos;
    if (index >= jugadoresVivos.length) return;

    // If the user enabled "skip pasa-teléfono" in settings, jump straight to
    // revealing the next player's role.
    final skip = context.read<PreferencesService>().skipPasaTelefono;
    if (skip) {
      verRol(jugadoresVivos[index]);
      return;
    }

    setState(() {
      _mostrandoPasarTelefono = true;
      _jugadorPasarIndex = index;
    });
  }

  /// Resolves emoji + optional image for the secret character.
  /// Returns null in .$2 for custom themes or characters without an image.
  (String, String?) _resolvePersonaje() {
    final personajes = tematicasData[widget.partida.tematica];
    if (personajes == null) return ('🎭', null);
    final personaje = personajes.firstWhere(
      (p) => p.nombre == widget.partida.personajeSecreto,
      orElse: () => personajes.first,
    );
    return (personaje.emoji, personaje.imagen);
  }

  void verRol(Jugador jugador) {
    if (jugador.esImpostor) {
      AudioService.playImpostor();
    } else {
      AudioService.playReveal();
    }
    _flipController.forward(from: 0);
    _confettiController.play();
    setState(() {
      jugadorActual = jugador;
      mostrandoRol = true;
      jugador.haVisto = true;
      _mostrandoPasarTelefono = false;
    });
  }

  void ocultarRol() {
    setState(() {
      mostrandoRol = false;
      jugadorActual = null;
    });

    // Show pasa-teléfono for the next player who hasn't seen their role yet.
    final jugadoresVivos = widget.partida.jugadoresVivos;
    final nextIndex = jugadoresVivos.indexWhere((j) => !j.haVisto);
    if (nextIndex != -1) {
      _mostrarPasarTelefono(nextIndex);
    }
  }

  bool todosVieron() {
    return widget.partida.jugadores
        .where((j) => j.estaVivo)
        .every((j) => j.haVisto);
  }

  void irAVotacion() {
    widget.partidaManager.iniciarRonda();
    Navigator.push(
      context,
      FadeScalePageRoute(
        page: VotacionScreen(
          partida: widget.partida,
          partidaManager: widget.partidaManager,
          sesion: widget.sesion,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  /// Confirma antes de abandonar la revelación. Salir vuelve a la sala y la
  /// ronda se reinicia (se reparten los roles de nuevo), así que un atrás
  /// accidental ya no descarta la ronda en curso sin avisar.
  Future<void> _confirmarSalirRevelacion() async {
    final salir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.exit_to_app, color: AppColors.danger),
            const SizedBox(width: 10),
            Text('¿Salir de la revelación?', style: AppTheme.titleLarge),
          ],
        ),
        content: Text(
          'Volverás a la sala y esta ronda se reiniciará (se repartirán los '
          'roles de nuevo).',
          style: AppTheme.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir',
                style: TextStyle(
                    color: AppColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (salir == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // PopScope intercepta el atrás del sistema; la flecha ← del grid usa
    // `_confirmarSalirRevelacion` directamente (PopScope no intercepta
    // llamadas explícitas a Navigator.pop).
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmarSalirRevelacion();
      },
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Pasa-teléfono handoff screen.
    if (_mostrandoPasarTelefono) {
      final jugadoresVivos = widget.partida.jugadoresVivos;
      if (_jugadorPasarIndex < jugadoresVivos.length) {
        final jugador = jugadoresVivos[_jugadorPasarIndex];
        return PasarTelefonoScreen(
          nombreJugador: jugador.nombre,
          numeroJugador: _jugadorPasarIndex + 1,
          totalJugadores: jugadoresVivos.length,
          onReady: () => verRol(jugador),
        );
      }
    }

    // Role-reveal screen.
    if (mostrandoRol && jugadorActual != null) {
      return _buildRolReveal();
    }

    // Fallback player-grid (tap to reveal).
    return _buildPlayerGrid();
  }

  // ---------------------------------------------------------------------------
  // Role reveal — "ícono protagonista" layout (V4)
  // ---------------------------------------------------------------------------

  Widget _buildRolReveal() {
    final esImpostor = jugadorActual!.esImpostor;

    // Read the user's preference once per build.
    final colorful = context.read<PreferencesService>().colorfulReveal;

    // ── Background colors ────────────────────────────────────────────────────
    // DISCREET (default, colorful == false):
    //   Both impostor AND civil use the same darkBgGradient → the ambient
    //   color of the screen does NOT reveal which role was drawn.
    // COLORFUL (opt-in):
    //   Impostor → dark red gradient; civil → dark green gradient.
    final List<Color> bgColors = colorful
        ? (esImpostor
            ? [AppColors.dangerDark, AppColors.danger]
            : [AppColors.safeDark, AppColors.safe])
        : AppColors.darkBgGradient;

    // ── Role-accent colors (ring, chip, glow) ────────────────────────────────
    final accentColor = esImpostor ? AppColors.danger : AppColors.safe;
    final accentDark = esImpostor ? AppColors.dangerDark : AppColors.safeDark;

    // ── Confetti colors ──────────────────────────────────────────────────────
    // Discreet mode: whites + a touch of role accent at low presence.
    // Colorful mode: vivid per-role palette.
    final List<Color> confettiColors = colorful
        ? (esImpostor
            ? const [
                Color(0xFFE0223E),
                Color(0xFF8B0E22),
                Color(0xFFFF5C72),
                Colors.white,
              ]
            : const [
                Color(0xFF22C55E),
                Color(0xFF16A34A),
                Color(0xFF4ADE80),
                Colors.white,
              ])
        : [
            Colors.white,
            Colors.white70,
            accentColor.withValues(alpha: 0.45),
            Colors.white54,
          ];

    // ── Label text: muted on dark bg, white on colored bg ───────────────────
    final labelColor =
        colorful ? AppColors.textPrimary : AppColors.textMuted;
    final playerNameColor =
        colorful ? AppColors.textPrimary : AppColors.textSecondary;

    return Scaffold(
      body: Stack(
        children: [
          // Background
          GradientBackground(
            colors: bgColors,
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 32,
                  ),
                  child: FadeTransition(
                    opacity: _flipAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // ── 1. Player name ──────────────────────────────────
                        Text(
                          jugadorActual!.nombre,
                          style: AppType.titleM.copyWith(color: playerNameColor),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 28),

                        // ── 2. Circular ring with role icon / avatar ────────
                        SizedBox(
                          width: 200,
                          height: 200,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outward pulse ring — runs once on reveal.
                              TweenAnimationBuilder<double>(
                                key: ValueKey('pulse-${jugadorActual!.id}'),
                                tween: Tween(begin: 0.6, end: 1.6),
                                duration: const Duration(milliseconds: 1100),
                                curve: Curves.easeOut,
                                builder: (context, value, _) {
                                  return Opacity(
                                    opacity: (1.6 - value).clamp(0.0, 1.0),
                                    child: Transform.scale(
                                      scale: value,
                                      child: Container(
                                        width: 130,
                                        height: 130,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: accentColor.withValues(
                                                alpha: 0.7),
                                            width: 3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),

                              // Static ring with role-tinted fill.
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: accentColor,
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accentColor.withValues(alpha: 0.35),
                                      blurRadius: 32,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: esImpostor
                                    ? const Center(
                                        child: Text(
                                          '☠️',
                                          style: TextStyle(fontSize: 48),
                                        ),
                                      )
                                    : _CharacterAvatar(
                                        size: 120,
                                        emoji: _emojiPersonaje,
                                        imagen: _imagenPersonaje,
                                        glowColor: accentColor.withValues(
                                            alpha: 0.3),
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── 3. Label ────────────────────────────────────────
                        Text(
                          esImpostor ? 'TU ROL' : 'EL PERSONAJE ES',
                          style: AppType.label.copyWith(
                            color: labelColor,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── 4. Role chip (pill) ─────────────────────────────
                        Container(
                          constraints: const BoxConstraints(maxWidth: 320),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(60),
                            boxShadow: [
                              BoxShadow(
                                color: accentDark.withValues(alpha: 0.5),
                                blurRadius: 18,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: esImpostor
                              ? Text(
                                  'IMPOSTOR',
                                  style: AppType.displayM.copyWith(
                                    color: AppColors.white,
                                    letterSpacing: 2,
                                  ),
                                  textAlign: TextAlign.center,
                                )
                              : AutoFitTitle(
                                  widget.partida.personajeSecreto,
                                  style: AppType.displayM.copyWith(
                                    color: AppColors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                        ),
                        const SizedBox(height: 20),

                        // ── 5. Helper text ──────────────────────────────────
                        Text(
                          esImpostor
                              ? 'No conoces el personaje. Disimula y\ndescúbrelo sin que te atrapen.'
                              : 'Hay un impostor entre ustedes.\nDescúbrelo sin revelar el personaje.',
                          style: AppType.body_.copyWith(
                            color: colorful
                                ? AppColors.white.withValues(alpha: 0.75)
                                : AppColors.textSecondary,
                            height: 1.55,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 36),

                        // ── 6. Hide button ──────────────────────────────────
                        AppButton(
                          text: 'Ocultar',
                          icon: Icons.visibility_off_rounded,
                          onPressed: ocultarRol,
                          variant: AppButtonVariant.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Confetti burst — top-center, fires once on reveal.
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: math.pi / 2, // downward
              maxBlastForce: 18,
              minBlastForce: 8,
              emissionFrequency: 0.05,
              numberOfParticles: 18,
              gravity: 0.25,
              shouldLoop: false,
              colors: confettiColors,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Player grid (fallback — tap your name to see your role)
  // ---------------------------------------------------------------------------

  Widget _buildPlayerGrid() {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                AppHeader(
                  title: widget.partida.tematica,
                  onBack: () {
                    AudioService.playClick();
                    _confirmarSalirRevelacion();
                  },
                ),
                const SizedBox(height: 16),

                AppCard(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.visibility_off_rounded,
                        size: 48,
                        color: AppColors.danger,
                      ),
                      const SizedBox(height: 12),
                      Text('¡Importante!', style: AppTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(
                        'Cada jugador debe ver su rol en secreto.\nNo muestren la pantalla a los demás.',
                        textAlign: TextAlign.center,
                        style: AppTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: widget.partida.jugadoresVivos.length,
                    itemBuilder: (context, index) {
                      final jugador =
                          widget.partida.jugadoresVivos[index];
                      final yaSee = jugador.haVisto;

                      return GestureDetector(
                        onTap: yaSee ? null : () => verRol(jugador),
                        child: AppCard(
                          gradient: yaSee ? null : AppColors.primaryGradient,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                yaSee
                                    ? Icons.check_circle_rounded
                                    : Icons.person_rounded,
                                size: 36,
                                color: yaSee
                                    ? AppColors.textMuted
                                    : AppColors.white,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                jugador.nombre,
                                style: AppType.titleM.copyWith(
                                  color: yaSee
                                      ? AppColors.textMuted
                                      : AppColors.white,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (yaSee)
                                const Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Ya vio',
                                    style: AppType.bodyS,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                if (todosVieron())
                  AppButton(
                    text: 'TODOS VIERON — CONTINUAR',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: irAVotacion,
                    variant: AppButtonVariant.safe,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CharacterAvatar
// ---------------------------------------------------------------------------

/// Circular avatar for the secret character: shows Image.asset(imagen)
/// (face-centered) if available, or the emoji as a fallback.
/// Useful for predefined themes with an image and custom themes without one.
class _CharacterAvatar extends StatelessWidget {
  const _CharacterAvatar({
    required this.size,
    required this.emoji,
    required this.imagen,
    required this.glowColor,
  });

  final double size;
  final String emoji;
  final String? imagen;
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    // cacheWidth: Flutter decodes the image at this resolution instead of the
    // native one. Dramatically reduces RAM usage and lag with large images
    // (1500×1500 from Wikipedia/MAL don't need to be full-res for a 120px
    // avatar). Use 2× the display size for HiDPI sharpness.
    final cacheSize = (size * 2).round();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: glowColor,
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: imagen == null
          ? Center(
              child: Text(
                emoji,
                style: TextStyle(fontSize: size * 0.45),
              ),
            )
          : ClipOval(
              child: Padding(
                padding: EdgeInsets.all(size * 0.06),
                child: Image.asset(
                  imagen!,
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                  cacheWidth: cacheSize,
                  cacheHeight: cacheSize,
                  errorBuilder: (_, __, ___) => Center(
                    child: Text(
                      emoji,
                      style: TextStyle(fontSize: size * 0.45),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
