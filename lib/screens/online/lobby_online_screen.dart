// lib/screens/online/lobby_online_screen.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/app_typography.dart';
import '../../data/tematicas_data.dart';
import '../../managers/partida_manager.dart';
import '../../managers/ronda_online_sync.dart';
import '../../managers/sala_online_manager.dart';
import '../../managers/sala_predicados.dart';
import '../../services/firebase_sala_gateway.dart';
import '../../services/firebase_service.dart';
import '../../services/sala_gateway.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_components.dart';
import '../../widgets/auto_fit_title.dart';

class LobbyOnlineScreen extends StatefulWidget {
  const LobbyOnlineScreen({
    super.key,
    required this.codigo,
    required this.manager,
    required this.esHost,
    this.tematica,
  });

  final String codigo;
  final SalaOnlineManager manager;
  final bool esHost;
  final String? tematica;

  @override
  State<LobbyOnlineScreen> createState() => _LobbyOnlineScreenState();
}

class _LobbyOnlineScreenState extends State<LobbyOnlineScreen> {
  RondaOnlineSync? _sync;
  String? _personajeSecreto;

  Future<void> _confirmarSalir() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Salir de la sala?', style: AppType.titleL),
        content: Text(
          widget.esHost
              ? 'Si sales, la sala se cerrará para todos.'
              : 'Serás desconectado de la sala.',
          style: AppType.body_,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Salir',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmar == true && mounted) {
      await widget.manager.salir();
      if (mounted) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    }
  }

  Future<void> _empezarPartida() async {
    final firebase = context.read<FirebaseService?>();
    if (firebase == null) return;

    final tematica = widget.tematica;
    if (tematica == null) return;

    final personajes = tematicasData[tematica];
    if (personajes == null || personajes.isEmpty) return;

    _personajeSecreto ??=
        personajes[Random().nextInt(personajes.length)].nombre;

    _sync ??= RondaOnlineSync(
      gateway: FirebaseSalaGateway(firebase.db),
      codigo: widget.codigo,
      uid: firebase.uid,
      manager: PartidaManager(),
    );

    await _sync!.iniciarPartida(personajeSecreto: _personajeSecreto!);
  }

  Widget _cuerpo(EstadoSala estado, Map<String, dynamic>? meta) {
    switch (estado) {
      case EstadoSala.lobby:
        return _LobbyView(
          codigo: widget.codigo,
          manager: widget.manager,
          esHost: widget.esHost,
          onSalir: _confirmarSalir,
          onEmpezar: _empezarPartida,
        );
      case EstadoSala.abandonada:
        return AppScaffold(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      size: 56, color: AppColors.textMuted),
                  const SizedBox(height: 20),
                  const Text(
                    'El anfitrión salió de la sala',
                    style: AppType.titleL,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  AppButton(
                    text: 'Volver al inicio',
                    icon: Icons.home_rounded,
                    variant: AppButtonVariant.secondary,
                    onPressed: () async {
                      await widget.manager.salir();
                      if (mounted) {
                        Navigator.of(context).popUntil((r) => r.isFirst);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      default:
        // Fases revelando/discusion/votando/resultado/finalizada —
        // placeholder para Phase 8.
        return AppScaffold(
          child: Center(
            child: Text(
              'Fase: ${estado.name}\n(en construcción)',
              style: AppType.titleM,
              textAlign: TextAlign.center,
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmarSalir();
      },
      child: StreamBuilder<Map<String, dynamic>?>(
        stream: widget.manager.observarMeta(widget.codigo),
        builder: (ctx, snap) {
          final estado =
              estadoSalaFromName(snap.data?['estado'] as String?);
          return _cuerpo(estado, snap.data);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Vista de lobby (estado == lobby)
// ---------------------------------------------------------------------------

class _LobbyView extends StatelessWidget {
  const _LobbyView({
    required this.codigo,
    required this.manager,
    required this.esHost,
    required this.onSalir,
    required this.onEmpezar,
  });

  final String codigo;
  final SalaOnlineManager manager;
  final bool esHost;
  final VoidCallback onSalir;
  final Future<void> Function() onEmpezar;

  void _copiarCodigo(BuildContext context) {
    Clipboard.setData(ClipboardData(text: codigo));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Código copiado')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Column(
        children: [
          AppHeader(
            title: 'Sala online',
            onBack: onSalir,
          ),

          // Código grande + copiar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('CÓDIGO DE SALA', style: AppType.label),
                        const SizedBox(height: 6),
                        AutoFitTitle(
                          codigo,
                          style: AppType.displayL.copyWith(letterSpacing: 10),
                          textAlign: TextAlign.left,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded,
                        color: AppColors.textSecondary),
                    tooltip: 'Copiar código',
                    onPressed: () => _copiarCodigo(context),
                  ),
                ],
              ),
            ),
          ),

          // Lista de jugadores
          Expanded(
            child: StreamBuilder<List<JugadorSala>>(
              stream: manager.observarJugadores(codigo),
              builder: (ctx, snap) {
                final jugadores = snap.data ?? [];
                final firebase = context.read<FirebaseService?>();
                final miUid = firebase?.uid;

                final yaListo = jugadores
                    .where((j) => j.uid == miUid)
                    .map((j) => j.listo)
                    .firstOrNull ?? false;

                return Column(
                  children: [
                    // Cabecera jugadores
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 4),
                      child: Row(
                        children: [
                          Text('JUGADORES (${jugadores.length})',
                              style: AppType.label),
                        ],
                      ),
                    ),

                    // Lista
                    Expanded(
                      child: jugadores.isEmpty
                          ? const Center(
                              child: Text(
                                'Esperando jugadores…',
                                style: AppType.body_,
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 4),
                              itemCount: jugadores.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final j = jugadores[i];
                                return _JugadorRow(
                                    jugador: j, miUid: miUid);
                              },
                            ),
                    ),

                    // Botones inferiores
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: Column(
                        children: [
                          // Toggle listo
                          AppButton(
                            text: yaListo
                                ? 'No estoy listo'
                                : 'Estoy listo',
                            icon: yaListo
                                ? Icons.close_rounded
                                : Icons.check_rounded,
                            variant: yaListo
                                ? AppButtonVariant.secondary
                                : AppButtonVariant.safe,
                            onPressed: () =>
                                manager.marcarListo(!yaListo),
                          ),
                          const SizedBox(height: 12),

                          // Botón empezar (solo host)
                          if (esHost)
                            AppButton(
                              text: 'Empezar partida',
                              icon: Icons.play_arrow_rounded,
                              onPressed: puedeIniciar(jugadores)
                                  ? onEmpezar
                                  : null,
                            )
                          else
                            const Text(
                              'Esperando a que el anfitrión empiece…',
                              style: AppType.bodyS,
                              textAlign: TextAlign.center,
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _JugadorRow extends StatelessWidget {
  const _JugadorRow({required this.jugador, required this.miUid});

  final JugadorSala jugador;
  final String? miUid;

  @override
  Widget build(BuildContext context) {
    final esMio = jugador.uid == miUid;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderColor:
          esMio ? AppColors.danger.withValues(alpha: 0.4) : null,
      child: Row(
        children: [
          // Dot conectado/desconectado
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: jugador.conectado
                  ? AppColors.safe
                  : AppColors.textMuted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),

          // Nombre
          Expanded(
            child: Text(
              jugador.nombre + (esMio ? ' (tú)' : ''),
              style: AppType.titleM.copyWith(
                color: esMio
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),

          // Check si listo
          if (jugador.listo)
            const Icon(Icons.check_circle_rounded,
                size: 20, color: AppColors.safe),
        ],
      ),
    );
  }
}
