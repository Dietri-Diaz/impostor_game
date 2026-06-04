// lib/screens/online/discusion_online_view.dart

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/app_typography.dart';
import '../../managers/ronda_online_sync.dart';
import '../../managers/sala_online_manager.dart';
import '../../services/sala_gateway.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_components.dart';

/// Vista de discusión para el modo online.
/// Muestra quién empieza a describir, las reglas del turno y (para el host)
/// el botón para abrir la votación cuando el grupo esté listo.
class DiscusionOnlineView extends StatelessWidget {
  const DiscusionOnlineView({
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
          const AppHeader(title: 'Discusión'),
          Expanded(
            child: StreamBuilder<Map<String, dynamic>?>(
              stream: manager.observarMeta(codigo),
              builder: (context, metaSnap) {
                final jugadorInicialUid =
                    metaSnap.data?['jugadorInicialUid'] as String?;

                return StreamBuilder<List<JugadorSala>>(
                  stream: manager.observarJugadores(codigo),
                  builder: (context, jugSnap) {
                    final jugadores = jugSnap.data ?? [];

                    // Resolve the starting player's name from the uid
                    final String nombreInicial;
                    if (jugadorInicialUid == null) {
                      nombreInicial = '…';
                    } else {
                      final match = jugadores
                          .where((j) => j.uid == jugadorInicialUid)
                          .map((j) => j.nombre)
                          .firstOrNull;
                      nombreInicial = match ?? jugadorInicialUid;
                    }

                    return _DiscusionBody(
                      nombreInicial: nombreInicial,
                      esHost: esHost,
                      sync: sync,
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

class _DiscusionBody extends StatelessWidget {
  const _DiscusionBody({
    required this.nombreInicial,
    required this.esHost,
    required this.sync,
  });

  final String nombreInicial;
  final bool esHost;
  final RondaOnlineSync? sync;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),

          // Starting player card
          AppCard(
            child: Column(
              children: [
                const Text(
                  'EMPIEZA',
                  style: AppType.label,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🗣️', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        nombreInicial,
                        style: AppType.displayM,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Hint card
          const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¿Cómo jugar?', style: AppType.titleM),
                SizedBox(height: 8),
                Text(
                  'Describan al personaje por turnos sin decirlo. '
                  'El impostor improvisa.',
                  style: AppType.body_,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Host controls / non-host waiting message
          if (esHost && sync != null) ...[
            AppButton(
              text: 'Abrir votación',
              icon: Icons.how_to_vote_rounded,
              variant: AppButtonVariant.danger,
              onPressed: () => sync!.abrirVotacion(),
            ),
          ] else ...[
            const Text(
              'Esperando a que el anfitrión abra la votación…',
              style: AppType.body_,
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
