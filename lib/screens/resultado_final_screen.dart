// lib/screens/resultado_final_screen.dart

import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../core/app_theme.dart';
import '../core/app_typography.dart';
import '../models/partida.dart';
import '../models/sesion_juego.dart';
import '../data/tematicas_data.dart';
import '../managers/partida_manager.dart';
import '../core/enums.dart';
import '../services/audio_service.dart';
import '../widgets/auto_fit_title.dart';
import '../widgets/app_button.dart';
import 'home_screen.dart';
import 'lobby_screen.dart';

class ResultadoFinalScreen extends StatefulWidget {
  final Partida partida;
  final PartidaManager partidaManager;
  final SesionJuego? sesion;

  const ResultadoFinalScreen({
    super.key,
    required this.partida,
    required this.partidaManager,
    this.sesion,
  });

  @override
  State<ResultadoFinalScreen> createState() => _ResultadoFinalScreenState();
}

class _ResultadoFinalScreenState extends State<ResultadoFinalScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 4));
    if (widget.partida.ganador == TipoGanador.jugadores) {
      _confettiController.play();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  (String, String?) _getPersonajeData() {
    final personajes = tematicasData[widget.partida.tematica];
    if (personajes == null) return ('❓', null);
    final personaje = personajes.firstWhere(
      (p) => p.nombre == widget.partida.personajeSecreto,
      orElse: () => personajes.first,
    );
    return (personaje.emoji, personaje.imagen);
  }

  @override
  Widget build(BuildContext context) {
    final impostores = widget.partida.impostores;
    final ganaron = widget.partida.ganador == TipoGanador.jugadores;
    final sesion = widget.sesion;
    final hayMultiples = impostores.length > 1;

    // accent: green = victory, red = defeat
    final Color accent = ganaron ? AppColors.safe : AppColors.danger;

    return Scaffold(
      body: Stack(
        children: [
          GradientBackground(
            colors: AppColors.darkBgGradient,
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon circle — tinted with accent
                      Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accent.withValues(alpha: 0.35),
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          ganaron
                              ? Icons.celebration_rounded
                              : Icons.sentiment_very_dissatisfied_rounded,
                          size: 80,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 25),

                      // Title in accent colour
                      AutoFitTitle(
                        ganaron ? '¡VICTORIA!' : '¡EL IMPOSTOR GANA!',
                        style: AppType.displayL.copyWith(color: accent),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),

                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: accent.withValues(alpha: 0.30)),
                        ),
                        child: Text(
                          ganaron
                              ? (hayMultiples
                                  ? 'Eliminaron a los impostores'
                                  : 'Eliminaron al impostor')
                              : (hayMultiples
                                  ? 'Los impostores sobrevivieron'
                                  : 'El impostor sobrevivió'),
                          style: AppType.bodyS.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Character reveal card — dark AppCard
                      AppCard(
                        child: Column(
                          children: [
                            Text(
                              'El personaje era:',
                              style: AppType.body_
                                  .copyWith(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 16),
                            Builder(
                              builder: (_) {
                                final (emoji, imagen) = _getPersonajeData();
                                return Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceHigh,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: accent.withValues(alpha: 0.50),
                                      width: 3,
                                    ),
                                  ),
                                  child: imagen == null
                                      ? Center(
                                          child: Text(
                                            emoji,
                                            style: const TextStyle(
                                                fontSize: 55),
                                          ),
                                        )
                                      : ClipOval(
                                          child: Padding(
                                            padding: const EdgeInsets.all(6),
                                            child: Image.asset(
                                              imagen,
                                              width: 100,
                                              height: 100,
                                              fit: BoxFit
                                                  .contain, // personaje completo
                                              cacheWidth: 200,
                                              cacheHeight: 200,
                                              errorBuilder: (_, __, ___) =>
                                                  Center(
                                                child: Text(
                                                  emoji,
                                                  style: const TextStyle(
                                                      fontSize: 55),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            AutoFitTitle(
                              widget.partida.personajeSecreto,
                              style: AppType.displayM.copyWith(
                                color: AppColors.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const Padding(
                              padding:
                                  EdgeInsets.symmetric(vertical: 20),
                              child: Divider(
                                  thickness: 1,
                                  color: AppColors.border),
                            ),
                            Text(
                              hayMultiples
                                  ? 'Los impostores eran:'
                                  : 'El impostor era:',
                              style: AppType.body_
                                  .copyWith(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: impostores.map((imp) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.danger
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                        color: AppColors.danger
                                            .withValues(alpha: 0.40),
                                        width: 2),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.person_rounded,
                                          color: AppColors.danger, size: 22),
                                      const SizedBox(width: 6),
                                      Text(
                                        imp.nombre,
                                        style: AppType.titleL.copyWith(
                                          color: AppColors.danger,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Stats — dark AppCard
                      AppCard(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.bar_chart_rounded,
                                    color: AppColors.textSecondary, size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  'Estadísticas',
                                  style: AppType.titleM
                                      .copyWith(color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStat(
                                    '${widget.partida.rondas.length}',
                                    'Rondas',
                                    Icons.refresh_rounded),
                                _buildStat(
                                    '${widget.partida.numeroJugadores}',
                                    'Jugadores',
                                    Icons.people_rounded),
                                _buildStat(
                                    '${widget.partida.jugadores.where((j) => !j.estaVivo).length}',
                                    'Eliminados',
                                    Icons.person_off_rounded),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Session scoreboard
                      if (sesion != null && sesion.rondasJugadas > 0) ...[
                        const SizedBox(height: 16),
                        AppCard(
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.emoji_events_rounded,
                                      color: AppColors.gold, size: 22),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Puntuación de Sesión',
                                    style: AppType.titleM
                                        .copyWith(color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ...sesion.rankingOrdenado
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                final index = entry.key;
                                final jugador = entry.value;
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 28,
                                        child: Text(
                                          index == 0
                                              ? '🥇'
                                              : index == 1
                                                  ? '🥈'
                                                  : index == 2
                                                      ? '🥉'
                                                      : '${index + 1}.',
                                          style:
                                              const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          jugador.key,
                                          style: AppType.body_.copyWith(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: index == 0
                                              ? AppColors.gold
                                              : AppColors.surfaceHigh,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: index == 0
                                              ? null
                                              : Border.all(
                                                  color: AppColors.border),
                                        ),
                                        child: Text(
                                          '${jugador.value} pts',
                                          style: AppType.bodyS.copyWith(
                                            color: index == 0
                                                ? Colors.black87
                                                : AppColors.textPrimary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 30),

                      // Buttons
                      if (sesion != null) ...[
                        AppButton(
                          text: 'JUGAR OTRA RONDA',
                          icon: Icons.replay_rounded,
                          variant: AppButtonVariant.safe,
                          onPressed: () {
                            AudioService.playClick();
                            Navigator.pushAndRemoveUntil(
                              context,
                              FadeScalePageRoute(
                                  page: LobbyScreen(sesion: sesion)),
                              (route) => false,
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      AppButton(
                        text: 'VOLVER AL INICIO',
                        icon: Icons.home_rounded,
                        variant: AppButtonVariant.primary,
                        onPressed: () {
                          AudioService.playClick();
                          widget.partidaManager.reiniciar();
                          Navigator.pushAndRemoveUntil(
                            context,
                            FadeScalePageRoute(
                                page: const HomeScreen()),
                            (route) => false,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Confetti — discreet palette (whites + greens + gold), on victory only
          if (ganaron)
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Colors.white,
                  Color(0xFFE8F5E9), // light green
                  AppColors.safe,
                  AppColors.gold,
                  Color(0xFFFFF8DC), // cream/gold-light
                ],
                numberOfParticles: 18,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppType.displayM.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppType.bodyS
                .copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
