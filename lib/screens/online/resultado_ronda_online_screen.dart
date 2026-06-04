// lib/screens/online/resultado_ronda_online_screen.dart

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/app_typography.dart';
import '../../managers/ronda_online_sync.dart';
import '../../managers/sala_online_manager.dart';
import '../../services/sala_gateway.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_components.dart';
import '../../widgets/auto_fit_title.dart';

class ResultadoRondaOnlineView extends StatelessWidget {
  const ResultadoRondaOnlineView({
    super.key,
    required this.codigo,
    required this.manager,
    required this.esHost,
    this.sync,
  });

  final String codigo;
  final SalaOnlineManager manager;
  final bool esHost;
  final RondaOnlineSync? sync;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Column(
        children: [
          const AppHeader(title: 'Resultado de ronda'),
          Expanded(
            child: StreamBuilder<Map<String, dynamic>?>(
              stream: manager.observarPublico(codigo),
              builder: (context, publicoSnap) {
                return StreamBuilder<List<JugadorSala>>(
                  stream: manager.observarJugadores(codigo),
                  builder: (context, jugSnap) {
                    final publico = publicoSnap.data;
                    final jugadores = jugSnap.data ?? [];

                    if (publico == null) {
                      return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.textSecondary),
                      );
                    }

                    final resultadoRonda =
                        (publico['resultadoRonda'] as Map?)
                            ?.cast<String, dynamic>();
                    final eliminadoUid =
                        resultadoRonda?['eliminadoUid'] as String?;
                    final eraImpostor =
                        (resultadoRonda?['eraImpostor'] as bool?) ?? false;
                    final ganador = publico['ganador'] as String?;

                    // Resolve eliminated player name
                    final String? nombreEliminado = eliminadoUid == null
                        ? null
                        : jugadores
                            .where((j) => j.uid == eliminadoUid)
                            .map((j) => j.nombre)
                            .firstOrNull;

                    // Determine accent colour
                    final Color accent;
                    if (eliminadoUid == null) {
                      accent = const Color(0xFFF59E0B); // amber — tie
                    } else if (eraImpostor) {
                      accent = AppColors.safe;
                    } else {
                      accent = AppColors.danger;
                    }

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),

                          // Icon circle
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
                              eliminadoUid == null
                                  ? Icons.balance_rounded
                                  : eraImpostor
                                      ? Icons.celebration_rounded
                                      : Icons.person_off_rounded,
                              size: 64,
                              color: accent,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Main title
                          AutoFitTitle(
                            eliminadoUid == null
                                ? '¡EMPATE!'
                                : eraImpostor
                                    ? '¡ERA EL IMPOSTOR!'
                                    : 'FIN DE RONDA',
                            style: AppType.displayL.copyWith(color: accent),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),

                          // Elimination card
                          AppCard(
                            child: Column(
                              children: [
                                if (eliminadoUid == null) ...[
                                  const Icon(Icons.people_rounded,
                                      size: 48,
                                      color: Color(0xFFF59E0B)),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Nadie fue eliminado (empate)',
                                    style: AppType.titleL,
                                    textAlign: TextAlign.center,
                                  ),
                                ] else ...[
                                  Icon(
                                    eraImpostor
                                        ? Icons.check_circle_rounded
                                        : Icons.person_off_rounded,
                                    size: 48,
                                    color: eraImpostor
                                        ? AppColors.safe
                                        : AppColors.danger,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Jugador eliminado:',
                                    style: AppType.body_.copyWith(
                                        color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: eraImpostor
                                          ? AppColors.safe
                                              .withValues(alpha: 0.12)
                                          : AppColors.danger
                                              .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: eraImpostor
                                            ? AppColors.safe
                                                .withValues(alpha: 0.35)
                                            : AppColors.danger
                                                .withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: AutoFitTitle(
                                      nombreEliminado ??
                                          eliminadoUid,
                                      style: AppType.displayM.copyWith(
                                        color: eraImpostor
                                            ? AppColors.safe
                                            : AppColors.textPrimary,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Divider(
                                      thickness: 1,
                                      color: AppColors.border),
                                  const SizedBox(height: 14),
                                  Text(
                                    eraImpostor
                                        ? '¡Era impostor! ✅'
                                        : 'No era el impostor ❌',
                                    style: AppType.titleL.copyWith(
                                      color: eraImpostor
                                          ? AppColors.safe
                                          : AppColors.danger,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Host controls
                          if (esHost && sync != null) ...[
                            if (ganador == null) ...[
                              AppButton(
                                text: 'Siguiente ronda',
                                icon: Icons.arrow_forward_rounded,
                                variant: AppButtonVariant.primary,
                                onPressed: () => sync!.siguienteRonda(),
                              ),
                            ] else ...[
                              AppButton(
                                text: 'Ver resultado final',
                                icon: Icons.emoji_events_rounded,
                                variant: AppButtonVariant.primary,
                                onPressed: () => sync!.irAFinal(),
                              ),
                            ],
                          ] else ...[
                            Text(
                              'Esperando al anfitrión…',
                              style: AppType.body_.copyWith(
                                  color: AppColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ],

                          const SizedBox(height: 24),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
