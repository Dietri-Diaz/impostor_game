// lib/screens/online/lobby_online_screen.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/app_typography.dart';
import '../../data/tematicas_data.dart';
import 'discusion_online_view.dart';
import 'resultado_final_online_screen.dart';
import 'resultado_ronda_online_screen.dart';
import 'revelar_rol_online_screen.dart';
import 'votacion_online_screen.dart';
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
  bool _iniciando = false;

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

  Future<void> _nuevaPartida() async {
    try {
      await _sync?.volverAlLobby();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo reiniciar: $e')),
        );
      }
      return;
    }
    if (mounted) {
      setState(() {
        _personajeSecreto = null;
        _iniciando = false;
      });
    }
  }

  Future<void> _empezarPartida() async {
    if (_iniciando) return; // evita doble toque
    final firebase = context.read<FirebaseService?>();
    if (firebase == null) return;

    final tematica = widget.tematica;
    if (tematica == null) return;

    final personajes = tematicasData[tematica];
    if (personajes == null || personajes.isEmpty) return;

    _iniciando = true;
    _personajeSecreto ??=
        personajes[Random().nextInt(personajes.length)].nombre;

    _sync ??= RondaOnlineSync(
      gateway: FirebaseSalaGateway(firebase.db),
      codigo: widget.codigo,
      uid: firebase.uid,
      manager: PartidaManager(),
    );

    try {
      await _sync!.iniciarPartida(personajeSecreto: _personajeSecreto!);
      // Al iniciar, meta.estado pasa a 'revelando' y el router cambia de vista;
      // dejamos _iniciando en true (ya no volvemos al lobby).
    } catch (e) {
      _iniciando = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo empezar: $e')),
        );
      }
    }
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
      case EstadoSala.revelando:
        return RevelarRolOnlineView(
          codigo: widget.codigo,
          manager: widget.manager,
          esHost: widget.esHost,
          sync: _sync,
        );
      case EstadoSala.discusion:
        return DiscusionOnlineView(
          codigo: widget.codigo,
          manager: widget.manager,
          esHost: widget.esHost,
          sync: _sync,
        );
      case EstadoSala.votando:
        return VotacionOnlineView(
          codigo: widget.codigo,
          manager: widget.manager,
          esHost: widget.esHost,
          sync: _sync,
        );
      case EstadoSala.resultado:
        return ResultadoRondaOnlineView(
          codigo: widget.codigo,
          manager: widget.manager,
          esHost: widget.esHost,
          sync: _sync,
        );
      case EstadoSala.finalizada:
        return ResultadoFinalOnlineView(
          codigo: widget.codigo,
          manager: widget.manager,
          esHost: widget.esHost,
          sync: _sync,
          onNuevaPartida: _nuevaPartida,
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
                                unawaited(manager.marcarListo(!yaListo)),
                          ),
                          const SizedBox(height: 12),

                          // Botón empezar (solo host): requiere >=3 conectados
                          // y que TODOS los activos estén "listo".
                          if (esHost) ...[
                            Builder(
                              builder: (_) {
                                final activos_ = activos(jugadores);
                                final puedeEmpezar = puedeIniciar(jugadores) &&
                                    activos_.every((j) => j.listo);
                                return Column(
                                  children: [
                                    AppButton(
                                      text: 'Empezar partida',
                                      icon: Icons.play_arrow_rounded,
                                      onPressed:
                                          puedeEmpezar ? onEmpezar : null,
                                    ),
                                    if (!puedeEmpezar) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        activos_.length < 3
                                            ? 'Se necesitan al menos 3 jugadores'
                                            : 'Esperando a que todos estén listos…',
                                        style: AppType.bodyS,
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ] else
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
