// lib/screens/resultado_ronda_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/app_typography.dart';
import '../core/enums.dart';
import '../models/partida.dart';
import '../models/ronda.dart';
import '../models/sesion_juego.dart';
import '../managers/partida_manager.dart';
import '../services/audio_service.dart';
import '../widgets/auto_fit_title.dart';
import '../widgets/app_button.dart';
import 'resultado_final_screen.dart';
import 'votacion_screen.dart';
import 'lobby_screen.dart';

class ResultadoRondaScreen extends StatefulWidget {
  final Partida partida;
  final PartidaManager partidaManager;
  final Ronda ronda;
  final bool juegoTerminado;
  final SesionJuego? sesion;

  const ResultadoRondaScreen({
    super.key,
    required this.partida,
    required this.partidaManager,
    required this.ronda,
    required this.juegoTerminado,
    this.sesion,
  });

  @override
  State<ResultadoRondaScreen> createState() => _ResultadoRondaScreenState();
}

class _ResultadoRondaScreenState extends State<ResultadoRondaScreen> {
  bool _resultadoRegistrado = false;

  // Auto-retorno al lobby cuando termina la partida y hay sesión activa.
  static const int _segundosAutoRetorno = 8;
  Timer? _autoReturnTimer;
  int _segundosRestantes = _segundosAutoRetorno;
  bool _autoReturnCancelado = false;

  @override
  void initState() {
    super.initState();
    // Registrar resultado en sesión UNA sola vez cuando el juego termina
    if (widget.juegoTerminado && widget.sesion != null && !_resultadoRegistrado) {
      widget.sesion!.registrarResultado(
        partida: widget.partida,
        numeroRonda: widget.sesion!.rondasJugadas + 1,
      );
      _resultadoRegistrado = true;
      _iniciarAutoRetorno();
    }
  }

  @override
  void dispose() {
    _autoReturnTimer?.cancel();
    super.dispose();
  }

  void _iniciarAutoRetorno() {
    _autoReturnTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_segundosRestantes <= 1) {
        t.cancel();
        _volverAlLobby();
      } else {
        setState(() => _segundosRestantes--);
      }
    });
  }

  void _cancelarAutoRetorno() {
    if (_autoReturnCancelado) return;
    _autoReturnTimer?.cancel();
    setState(() => _autoReturnCancelado = true);
  }

  void _irASiguienteRonda() {
    AudioService.playClick();
    widget.partidaManager.siguienteRonda();

    // Reset haVisto para la siguiente ronda de votación
    for (var jugador in widget.partida.jugadoresVivos) {
      jugador.haVisto = false;
    }

    // Verificar ANTES de iniciar la ronda si el juego ya terminó
    // (ej: empate con 2 jugadores, o edge case)
    if (widget.partidaManager.verificarFinDeJuego()) {
      // Registrar resultado si no se hizo
      if (widget.sesion != null && !_resultadoRegistrado) {
        widget.sesion!.registrarResultado(
          partida: widget.partida,
          numeroRonda: widget.sesion!.rondasJugadas + 1,
        );
        _resultadoRegistrado = true;
      }
      Navigator.pushReplacement(
        context,
        FadeScalePageRoute(
          page: ResultadoFinalScreen(
            partida: widget.partida,
            partidaManager: widget.partidaManager,
            sesion: widget.sesion,
          ),
        ),
      );
      return;
    }

    widget.partidaManager.iniciarRonda();

    Navigator.pushReplacement(
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

  void _irAResultadoFinal() {
    _cancelarAutoRetorno();
    Navigator.pushReplacement(
      context,
      FadeScalePageRoute(
        page: ResultadoFinalScreen(
          partida: widget.partida,
          partidaManager: widget.partidaManager,
          sesion: widget.sesion,
        ),
      ),
    );
  }

  void _volverAlLobby() {
    _autoReturnTimer?.cancel();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      FadeScalePageRoute(page: LobbyScreen(sesion: widget.sesion!)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final jugadorEliminado = widget.ronda.jugadorEliminado;
    final huboEmpate = widget.ronda.huboEmpate && jugadorEliminado == null;
    final ganoImpostor =
        widget.juegoTerminado && widget.partida.ganador == TipoGanador.impostor;
    final ganaronCiviles = widget.juegoTerminado &&
        widget.partida.ganador == TipoGanador.jugadores;

    // accent: outcome colour — green=victory/impostor-elim, red=defeat/impostor-won, amber=tie
    final Color accent;
    if (ganaronCiviles || jugadorEliminado?.esImpostor == true) {
      accent = AppColors.safe;
    } else if (ganoImpostor) {
      accent = AppColors.danger;
    } else if (huboEmpate) {
      accent = const Color(0xFFF59E0B); // amber
    } else {
      // mid-round, non-terminal: neutral elimination
      accent = AppColors.danger;
    }

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _cancelarAutoRetorno,
        child: GradientBackground(
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
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accent.withValues(alpha: 0.35),
                          width: 3,
                        ),
                      ),
                      child: Icon(
                        ganoImpostor
                            ? Icons.sentiment_very_dissatisfied_rounded
                            : ganaronCiviles
                                ? Icons.celebration_rounded
                                : huboEmpate
                                    ? Icons.balance_rounded
                                    : jugadorEliminado?.esImpostor == true
                                        ? Icons.celebration_rounded
                                        : Icons.person_off_rounded,
                        size: 70,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 25),

                    // Main title in accent colour
                    AutoFitTitle(
                      ganoImpostor
                          ? '¡EL IMPOSTOR GANÓ!'
                          : ganaronCiviles
                              ? '¡CIVILES GANAN!'
                              : huboEmpate
                                  ? '¡EMPATE!'
                                  : 'FIN DE RONDA ${widget.ronda.numero}',
                      style: AppType.displayL.copyWith(color: accent),
                      textAlign: TextAlign.center,
                    ),
                    if (widget.juegoTerminado) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 6),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.30),
                          ),
                        ),
                        child: Text(
                          ganoImpostor
                              ? 'Los impostores sobrevivieron'
                              : 'Eliminaron al impostor',
                          style: AppType.bodyS.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 30),

                    // Info card — dark AppCard
                    AppCard(
                      child: Column(
                        children: [
                          if (huboEmpate) ...[
                            const Icon(Icons.people_rounded,
                                size: 50,
                                color: Color(0xFFF59E0B)),
                            const SizedBox(height: 16),
                            Text(
                              'Hubo empate en la votación',
                              style: AppType.titleL.copyWith(
                                color: const Color(0xFFF59E0B),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Nadie fue eliminado',
                              style: AppType.body_.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (widget.ronda.jugadoresEmpatados != null) ...[
                              const SizedBox(height: 16),
                              const Divider(
                                  thickness: 1,
                                  color: AppColors.border),
                              const SizedBox(height: 12),
                              Text(
                                'Jugadores empatados:',
                                style: AppType.bodyS.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children:
                                    widget.ronda.jugadoresEmpatados!.map((id) {
                                  final jugador = widget.partida.jugadores
                                      .firstWhere((j) => j.id == id);
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(0xFFF59E0B)
                                            .withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Text(
                                      jugador.nombre,
                                      style: AppType.bodyS.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFFF59E0B),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ] else if (jugadorEliminado != null) ...[
                            Icon(
                              jugadorEliminado.esImpostor
                                  ? Icons.check_circle_rounded
                                  : Icons.person_off_rounded,
                              size: 50,
                              color: jugadorEliminado.esImpostor
                                  ? AppColors.safe
                                  : AppColors.danger,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Jugador eliminado:',
                              style: AppType.body_.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 25, vertical: 12),
                              decoration: BoxDecoration(
                                color: jugadorEliminado.esImpostor
                                    ? AppColors.safe.withValues(alpha: 0.12)
                                    : AppColors.danger.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: jugadorEliminado.esImpostor
                                      ? AppColors.safe.withValues(alpha: 0.35)
                                      : AppColors.danger.withValues(alpha: 0.35),
                                ),
                              ),
                              child: AutoFitTitle(
                                jugadorEliminado.nombre,
                                style: AppType.displayM.copyWith(
                                  color: jugadorEliminado.esImpostor
                                      ? AppColors.safe
                                      : AppColors.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Divider(thickness: 1, color: AppColors.border),
                            const SizedBox(height: 16),
                            Text(
                              jugadorEliminado.esImpostor
                                  ? '¡ERA EL IMPOSTOR!'
                                  : 'NO ERA EL IMPOSTOR',
                              style: AppType.titleL.copyWith(
                                color: jugadorEliminado.esImpostor
                                    ? AppColors.safe
                                    : AppColors.danger,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Remaining players — dark AppCard (surface)
                    AppCard(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.people_rounded,
                                  color: AppColors.textSecondary, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                'Jugadores restantes: ${widget.partida.cantidadJugadoresVivos}',
                                style: AppType.titleM
                                    .copyWith(color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: widget.partida.jugadoresVivos.map((j) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceHigh,
                                  borderRadius: BorderRadius.circular(20),
                                  border:
                                      Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  j.nombre,
                                  style: AppType.bodyS.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Vote results — dark AppCard
                    if (widget.ronda.conteoVotos != null)
                      AppCard(
                        child: Column(
                          children: [
                            Text(
                              'Resultado de la votación:',
                              style: AppType.titleM
                                  .copyWith(color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 12),
                            ...widget.ronda.conteoVotos!.entries.map((entry) {
                              final jugador = widget.partida.jugadores
                                  .firstWhere((j) => j.id == entry.key);
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      jugador.nombre,
                                      style: AppType.bodyS.copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Icon(Icons.arrow_forward_rounded,
                                        color: AppColors.textMuted, size: 16),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceHigh,
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                            color: AppColors.border),
                                      ),
                                      child: Text(
                                        '${entry.value} ${entry.value == 1 ? "voto" : "votos"}',
                                        style: AppType.bodyS.copyWith(
                                          color: AppColors.textPrimary,
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
                    const SizedBox(height: 30),

                    // Action buttons
                    if (widget.juegoTerminado) ...[
                      if (widget.sesion != null &&
                          !_autoReturnCancelado &&
                          _autoReturnTimer != null &&
                          _autoReturnTimer!.isActive) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceHigh,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.timer_outlined,
                                  color: AppColors.textSecondary, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Volviendo al lobby en $_segundosRestantes... (toca para cancelar)',
                                style: AppType.bodyS.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      AppButton(
                        text: 'VER RESULTADO FINAL',
                        icon: Icons.emoji_events_rounded,
                        variant: AppButtonVariant.primary,
                        onPressed: _irAResultadoFinal,
                      ),
                      if (widget.sesion != null) ...[
                        const SizedBox(height: 12),
                        AppButton(
                          text: 'VOLVER AL LOBBY',
                          icon: Icons.replay_rounded,
                          variant: AppButtonVariant.secondary,
                          onPressed: _volverAlLobby,
                        ),
                      ],
                    ] else ...[
                      AppButton(
                        text: 'SIGUIENTE RONDA',
                        icon: Icons.arrow_forward_rounded,
                        variant: AppButtonVariant.primary,
                        onPressed: _irASiguienteRonda,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
