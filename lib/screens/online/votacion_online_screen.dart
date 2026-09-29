// lib/screens/online/votacion_online_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/app_typography.dart';
import '../../managers/ronda_online_sync.dart';
import '../../managers/sala_online_manager.dart';
import '../../managers/sala_predicados.dart';
import '../../services/sala_gateway.dart';
import '../../widgets/adaptive_avatar_grid.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_components.dart';

/// Paleta de colores de jugador por índice (cicla si hay más de 8).
const List<Color> _kPlayerColors = [
  Color(0xFFE0223E),
  Color(0xFF22C55E),
  Color(0xFF3B82F6),
  Color(0xFFF59E0B),
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
  Color(0xFF14B8A6),
  Color(0xFFF97316),
];

Color _colorForIndex(int index) => _kPlayerColors[index % _kPlayerColors.length];

/// Vista de votación online: cada jugador vota en su propio dispositivo.
class VotacionOnlineView extends StatefulWidget {
  const VotacionOnlineView({
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
  State<VotacionOnlineView> createState() => _VotacionOnlineViewState();
}

class _VotacionOnlineViewState extends State<VotacionOnlineView> {
  bool _yaVote = false;
  String? _pendiente; // uid del candidato pendiente de confirmación
  bool _resuelto = false;

  // HOST-only subscriptions
  StreamSubscription<Map<String, dynamic>?>? _subVotos;
  StreamSubscription<List<JugadorSala>>? _subJugadores;

  List<JugadorSala> _jugadoresActuales = [];
  Map<String, String> _votosActuales = {};

  @override
  void initState() {
    super.initState();
    // Al reconectar a mitad de votación, no volver a pedir un voto ya emitido.
    widget.manager.yaVote(widget.codigo).then((v) {
      if (v && mounted) setState(() => _yaVote = true);
    }).catchError((_) {});
    if (widget.esHost) {
      _subJugadores = widget.manager
          .observarJugadores(widget.codigo)
          .listen((jugadores) {
        _jugadoresActuales = jugadores;
        _checkAutoResolver();
      });

      _subVotos = widget.manager
          .observarVotos(widget.codigo)
          .listen((raw) {
        if (raw == null) {
          _votosActuales = {};
        } else {
          _votosActuales = {
            for (final e in raw.entries)
              if (e.value is Map)
                e.key: (e.value as Map)['objetivoUid'] as String,
          };
        }
        // Publish progress
        widget.sync?.publicarProgresoVotos(_votosActuales.length);
        _checkAutoResolver();
      });
    }
  }

  void _checkAutoResolver() {
    if (_resuelto) return;
    if (_jugadoresActuales.isEmpty) return;
    if (todosVotaron(_jugadoresActuales, _votosActuales)) {
      _resuelto = true;
      widget.sync?.contarVotosYResolver();
    }
  }

  @override
  void dispose() {
    _subVotos?.cancel();
    _subJugadores?.cancel();
    super.dispose();
  }

  Future<void> _confirmarVoto() async {
    final uid = _pendiente;
    if (uid == null || _yaVote) return;
    setState(() => _pendiente = null); // cierra la hoja de inmediato
    await widget.manager.votar(widget.codigo, uid);
    if (!mounted) return;
    setState(() => _yaVote = true);
  }

  void _cancelarConfirm() => setState(() => _pendiente = null);

  void _forzarCierre() {
    if (_resuelto) return;
    _resuelto = true;
    widget.sync?.contarVotosYResolver();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Column(
        children: [
          const AppHeader(title: 'Votación'),
          Expanded(
            child: StreamBuilder<List<JugadorSala>>(
              stream: widget.manager.observarJugadores(widget.codigo),
              builder: (context, jugSnap) {
                final jugadores = jugSnap.data ?? [];
                final votables = activos(jugadores);
                final total = votables.length;

                final avatarItems = [
                  for (var i = 0; i < votables.length; i++)
                    AvatarItem(
                      id: votables[i].uid,
                      label: votables[i].nombre,
                      color: _colorForIndex(i),
                    ),
                ];

                // Find the pending player's name for the sheet
                final pendienteNombre = _pendiente == null
                    ? null
                    : votables
                        .where((j) => j.uid == _pendiente)
                        .map((j) => j.nombre)
                        .firstOrNull;

                return Stack(
                  children: [
                    AnimatedPadding(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      padding: EdgeInsets.only(
                          bottom: _pendiente != null ? 160 : 0),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                        child: Column(
                          children: [
                            // Progress bar (uses publico stream for guests too)
                            StreamBuilder<Map<String, dynamic>?>(
                              stream: widget.manager
                                  .observarPublico(widget.codigo),
                              builder: (context, pubSnap) {
                                final emitidos = (pubSnap.data?['votosEmitidos']
                                        as int?) ??
                                    0;
                                final progreso =
                                    total == 0 ? 0.0 : emitidos / total;
                                return _ProgresoVotos(
                                  votosCount: emitidos,
                                  total: total,
                                  progreso: progreso,
                                );
                              },
                            ),
                            const SizedBox(height: 12),

                            // Main area
                            Expanded(
                              child: _yaVote
                                  ? _WaitingArea(
                                      total: total,
                                      manager: widget.manager,
                                      codigo: widget.codigo,
                                    )
                                  : AdaptiveAvatarGrid(
                                      items: avatarItems,
                                      selectedId: _pendiente,
                                      onTap: (item) {
                                        if (_yaVote) return;
                                        setState(
                                            () => _pendiente = item.id);
                                      },
                                    ),
                            ),

                            // HOST force-close button
                            if (widget.esHost && !_resuelto) ...[
                              const SizedBox(height: 8),
                              AppButton(
                                text: 'Cerrar votación',
                                icon: Icons.gavel_rounded,
                                variant: AppButtonVariant.secondary,
                                onPressed: _forzarCierre,
                              ),
                            ],
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),

                    // Scrim
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: _pendiente == null,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: _pendiente != null ? 1 : 0,
                          child: GestureDetector(
                            onTap: _cancelarConfirm,
                            child: const ColoredBox(
                                color: Color(0x4D000000)),
                          ),
                        ),
                      ),
                    ),

                    // Confirmation sheet
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      left: 0,
                      right: 0,
                      bottom: _pendiente != null ? 0 : -300,
                      child: _buildConfirmSheet(pendienteNombre),
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

  Widget _buildConfirmSheet(String? nombre) {
    if (nombre == null) return const SizedBox.shrink();
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Votar por $nombre?',
                      style: AppType.titleM.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Solo puedes votar una vez.',
                      style: AppType.bodyS,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: 'Cancelar',
                  variant: AppButtonVariant.secondary,
                  onPressed: _cancelarConfirm,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  text: 'Votar',
                  icon: Icons.how_to_vote_rounded,
                  variant: AppButtonVariant.danger,
                  onPressed: _confirmarVoto,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ProgresoVotos
// ---------------------------------------------------------------------------

class _ProgresoVotos extends StatelessWidget {
  const _ProgresoVotos({
    required this.votosCount,
    required this.total,
    required this.progreso,
  });

  final int votosCount;
  final int total;
  final double progreso;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.how_to_vote_rounded,
                  size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Elige al impostor',
                  style: AppType.titleM,
                ),
              ),
              Text(
                '$votosCount/$total votaron',
                style: AppType.bodyS,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progreso.clamp(0.0, 1.0),
              backgroundColor: AppColors.border,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.danger),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _WaitingArea — shown after the local player has voted
// ---------------------------------------------------------------------------

class _WaitingArea extends StatelessWidget {
  const _WaitingArea({
    required this.total,
    required this.manager,
    required this.codigo,
  });

  final int total;
  final SalaOnlineManager manager;
  final String codigo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.safe.withValues(alpha: 0.12),
                border: Border.all(color: AppColors.safe),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppColors.safe,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ya votaste',
              style: AppType.titleL,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            StreamBuilder<Map<String, dynamic>?>(
              stream: manager.observarPublico(codigo),
              builder: (context, snap) {
                final emitidos =
                    (snap.data?['votosEmitidos'] as int?) ?? 0;
                final restantes = total - emitidos;
                return Text(
                  restantes > 0
                      ? 'Esperando a $restantes más…'
                      : 'Esperando resultado…',
                  style: AppType.body_.copyWith(
                      color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
