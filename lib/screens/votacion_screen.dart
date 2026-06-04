// lib/screens/votacion_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/app_typography.dart';
import '../managers/partida_manager.dart';
import '../models/jugador.dart';
import '../models/partida.dart';
import '../models/sesion_juego.dart';
import '../services/audio_service.dart';
import '../widgets/adaptive_avatar_grid.dart';
import '../widgets/app_button.dart';
import '../widgets/auto_fit_title.dart';
import 'reglas_screen.dart';
import 'resultado_ronda_screen.dart';

class VotacionScreen extends StatefulWidget {
  final Partida partida;
  final PartidaManager partidaManager;
  final SesionJuego? sesion;

  const VotacionScreen({
    super.key,
    required this.partida,
    required this.partidaManager,
    this.sesion,
  });

  @override
  State<VotacionScreen> createState() => _VotacionScreenState();
}

class _VotacionScreenState extends State<VotacionScreen> {
  final Map<String, String> _votos = {};
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;
  // ValueNotifier evita rebuilds del Scaffold completo en cada tick:
  // solo el subárbol del TimerCard se reconstruye una vez por segundo.
  final ValueNotifier<int> _tiempoRestante = ValueNotifier(0);
  bool _discusionTerminada = false;
  bool _mostrarVotacionUnanime = false;
  String? _jugadorVotadoUnanime;
  bool _mostrandoHandoff = false;

  // Confirmación de voto/eliminación dentro de la pantalla (hoja deslizante).
  Jugador? _pendiente;        // visible mientras != null
  Jugador? _ultimoObjetivo;   // se mantiene durante la animación de salida
  bool _ultimoUnanime = false;

  @override
  void initState() {
    super.initState();
    _tiempoRestante.value = widget.partida.configuracion.segundosDiscusion;
    _iniciarTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    _tiempoRestante.dispose();
    super.dispose();
  }

  void _iniciarTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_tiempoRestante.value > 0) {
        _tiempoRestante.value--;
      } else {
        timer.cancel();
        setState(() => _discusionTerminada = true);
      }
    });
  }

  Jugador? get _votanteActual {
    for (final j in widget.partida.jugadoresVivos) {
      if (!_votos.containsKey(j.id)) return j;
    }
    return null;
  }

  void _confirmarVotoSecreto(Jugador votante, Jugador candidato) {
    setState(() {
      _pendiente = candidato;
      _ultimoObjetivo = candidato;
      _ultimoUnanime = false;
    });
  }

  void _continuarHandoff() {
    AudioService.playClick();
    setState(() => _mostrandoHandoff = false);
  }

  void _confirmarEliminarUnanime(Jugador objetivo) {
    setState(() {
      _pendiente = objetivo;
      _ultimoObjetivo = objetivo;
      _ultimoUnanime = true;
    });
  }

  void _cancelarConfirm() => setState(() => _pendiente = null);

  void _ejecutarConfirm() {
    final objetivo = _ultimoObjetivo;
    if (objetivo == null) return;
    if (_ultimoUnanime) {
      setState(() {
        _jugadorVotadoUnanime = objetivo.id;
        _pendiente = null;
      });
      _revelarResultado();
    } else {
      AudioService.playClick();
      final votante = _votanteActual; // sigue siendo el votante (aún no se registró)
      setState(() {
        if (votante != null) _votos[votante.id] = objetivo.id;
        _pendiente = null;
        _mostrandoHandoff = _votanteActual != null;
      });
    }
  }

  /// Hoja de confirmación dentro de la pantalla (sin showModalBottomSheet):
  /// se desliza desde abajo y la rejilla de caras sube para no taparse.
  Widget _buildConfirmSheet() {
    final obj = _ultimoObjetivo;
    if (obj == null) return const SizedBox.shrink();
    final titulo =
        _ultimoUnanime ? '¿Eliminar a ${obj.nombre}?' : '¿Votar por ${obj.nombre}?';
    final sub = _ultimoUnanime ? 'Voto unánime de todos.' : 'Tu voto es secreto.';
    final okLabel = _ultimoUnanime ? 'Eliminar' : 'Votar';
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
                    color: AppColors.danger, shape: BoxShape.circle),
                child: Text(
                  obj.nombre.isNotEmpty ? obj.nombre[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo,
                        style: AppType.titleM.copyWith(
                            fontWeight: FontWeight.w800, fontSize: 17)),
                    const SizedBox(height: 2),
                    Text(sub, style: AppType.bodyS),
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
                  text: okLabel,
                  icon: Icons.how_to_vote_rounded,
                  variant: AppButtonVariant.danger,
                  onPressed: _ejecutarConfirm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _todosVotaron() =>
      _votos.length == widget.partida.jugadoresVivos.length;

  void _saltarADiscusion() {
    setState(() {
      _discusionTerminada = true;
      _timer?.cancel();
    });
  }

  void _cambiarAVotoSecreto() {
    setState(() {
      _mostrarVotacionUnanime = false;
      _votos.clear();
      _jugadorVotadoUnanime = null;
    });
  }

  void _cambiarAVotoUnanime() {
    setState(() {
      _mostrarVotacionUnanime = true;
      _votos.clear();
      _jugadorVotadoUnanime = null;
    });
  }

  void _revelarResultado() {
    AudioService.playVictory();

    if (_mostrarVotacionUnanime && _jugadorVotadoUnanime != null) {
      _votos.clear();
      for (final jugador in widget.partida.jugadoresVivos) {
        _votos[jugador.id] = _jugadorVotadoUnanime!;
      }
    }

    final manager = widget.partidaManager;
    final conteoVotos = manager.procesarVotacion(_votos);
    final huboEmpate = manager.verificarEmpate(conteoVotos);
    final jugadorEliminadoId = manager.obtenerJugadorEliminado(
      conteoVotos,
      widget.partida.configuracion.eliminarEnEmpate,
    );

    final rondaActual = widget.partida.rondas.last;
    rondaActual.votos = _votos;
    rondaActual.conteoVotos = conteoVotos;
    rondaActual.huboEmpate = huboEmpate;

    if (huboEmpate && !widget.partida.configuracion.eliminarEnEmpate) {
      final maxVotos = conteoVotos.values.reduce((a, b) => a > b ? a : b);
      rondaActual.jugadoresEmpatados = conteoVotos.entries
          .where((e) => e.value == maxVotos)
          .map((e) => e.key)
          .toList();
    }

    if (jugadorEliminadoId != null) {
      manager.eliminarJugador(jugadorEliminadoId);
    }

    manager.finalizarRonda();
    final juegoTerminado = manager.verificarFinDeJuego();

    Navigator.pushReplacement(
      context,
      FadeScalePageRoute(
        page: ResultadoRondaScreen(
          partida: widget.partida,
          partidaManager: manager,
          ronda: rondaActual,
          juegoTerminado: juegoTerminado,
          sesion: widget.sesion,
        ),
      ),
    );
  }

  Future<void> _confirmarSalir() async {
    final salir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('¿Salir de la ronda?', style: AppTheme.titleLarge),
        content: Text(
          'Volverás al lobby y se perderá la discusión y los votos de esta ronda.',
          style: AppTheme.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
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

  String _formatearTiempo(int segundos) {
    final min = segundos ~/ 60;
    final seg = segundos % 60;
    return '${min.toString().padLeft(2, '0')}:${seg.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final jugadoresVivos = widget.partida.jugadoresVivos;
    final totalVivos = jugadoresVivos.length;
    // Evita división por cero si por algún edge case no quedan vivos.
    final progreso = totalVivos == 0 ? 0.0 : _votos.length / totalVivos;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmarSalir();
      },
      child: Scaffold(
        body: GradientBackground(
          child: SafeArea(
            child: Stack(
              children: [
                AnimatedPadding(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.only(bottom: _pendiente != null ? 184 : 0),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        AppHeader(
                          title: 'Ronda ${widget.partida.rondaActual}',
                          onBack: () {
                            AudioService.playClick();
                            _confirmarSalir();
                          },
                          actions: [
                            IconButton(
                              icon: const Icon(Icons.help_outline_rounded,
                                  color: AppColors.textPrimary),
                              onPressed: () {
                                AudioService.playClick();
                                Navigator.push(
                                  context,
                                  SlidePageRoute(page: const ReglasScreen()),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ValueListenableBuilder<int>(
                          valueListenable: _tiempoRestante,
                          builder: (context, tiempo, _) {
                            return _TimerCard(
                              discusionTerminada: _discusionTerminada,
                              tiempoRestante: tiempo,
                              formatearTiempo: _formatearTiempo,
                              mostrarProgreso:
                                  _discusionTerminada && !_mostrarVotacionUnanime,
                              votosCount: _votos.length,
                              totalVivos: totalVivos,
                              progreso: progreso,
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        if (!_discusionTerminada)
                          _DiscussionPhase(
                            onSkip: _saltarADiscusion,
                            jugadorInicial: widget.partida.rondas.isNotEmpty
                                ? widget.partida.rondas.last.jugadorInicial?.nombre
                                : null,
                          )
                        else if (_mostrarVotacionUnanime)
                          _UnanimousVotingPhase(
                            jugadoresVivos: jugadoresVivos,
                            onTapJugador: _confirmarEliminarUnanime,
                            onCambiarASecreto: _cambiarAVotoSecreto,
                          )
                        else
                          _SecretVotingPhase(
                            jugadoresVivos: jugadoresVivos,
                            votanteActual: _votanteActual,
                            mostrandoHandoff: _mostrandoHandoff,
                            votosCount: _votos.length,
                            totalVivos: totalVivos,
                            onTapCandidato: _confirmarVotoSecreto,
                            onContinuarHandoff: _continuarHandoff,
                            onCambiarAUnanime: _cambiarAVotoUnanime,
                            todosVotaron: _todosVotaron(),
                            onRevelar: _revelarResultado,
                          ),
                      ],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: _pendiente == null,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _pendiente != null ? 1 : 0,
                      child: GestureDetector(
                        onTap: _cancelarConfirm,
                        child: const ColoredBox(color: Color(0x4D000000)),
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  left: 0,
                  right: 0,
                  bottom: _pendiente != null ? 0 : -300,
                  child: _buildConfirmSheet(),
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
// _TimerCard
// ---------------------------------------------------------------------------

class _TimerCard extends StatelessWidget {
  const _TimerCard({
    required this.discusionTerminada,
    required this.tiempoRestante,
    required this.formatearTiempo,
    required this.mostrarProgreso,
    required this.votosCount,
    required this.totalVivos,
    required this.progreso,
  });

  final bool discusionTerminada;
  final int tiempoRestante;
  final String Function(int) formatearTiempo;
  final bool mostrarProgreso;
  final int votosCount;
  final int totalVivos;
  final double progreso;

  @override
  Widget build(BuildContext context) {
    final urgente = tiempoRestante < 10 && !discusionTerminada;
    final timerColor = urgente ? AppColors.danger : AppColors.textPrimary;

    return AppCard(
      child: Column(
        children: [
          Icon(
            discusionTerminada
                ? Icons.how_to_vote_rounded
                : Icons.timer_rounded,
            size: 36,
            color: urgente
                ? AppColors.danger
                : AppColors.textSecondary,
          ),
          const SizedBox(height: 8),
          Text(
            discusionTerminada ? '¡Tiempo de votar!' : 'Tiempo de discusión',
            style: AppType.titleM,
          ),
          const SizedBox(height: 6),
          if (!discusionTerminada) ...[
            AutoFitTitle(
              formatearTiempo(tiempoRestante),
              style: AppType.displayL.copyWith(color: timerColor),
            ),
          ] else ...[
            Text(
              'Todos deben votar',
              style: AppType.body_.copyWith(color: AppColors.textSecondary),
            ),
          ],
          if (!discusionTerminada)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Hagan preguntas sobre el personaje',
                style: AppType.bodyS,
              ),
            ),
          if (mostrarProgreso) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progreso,
                backgroundColor: AppColors.border,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.danger),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$votosCount/$totalVivos votaron',
              style: AppType.bodyS,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _DiscussionPhase
// ---------------------------------------------------------------------------

class _DiscussionPhase extends StatelessWidget {
  const _DiscussionPhase({required this.onSkip, this.jugadorInicial});

  final VoidCallback onSkip;
  final String? jugadorInicial;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: const Icon(
                Icons.question_answer_rounded,
                size: 64,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 28),
            const AutoFitTitle(
              'Discutan y descubran\nquién es el impostor',
              style: AppType.titleL,
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
            if (jugadorInicial != null) ...[
              const SizedBox(height: 24),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.safe.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.safe.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.record_voice_over_rounded,
                        color: AppColors.safe, size: 22),
                    const SizedBox(width: 10),
                    Flexible(
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: AppType.titleM,
                          children: [
                            const TextSpan(
                                text: 'Empieza: ',
                                style: TextStyle(
                                    color: AppColors.textSecondary)),
                            TextSpan(
                              text: jugadorInicial!,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            AppButton(
              text: 'Saltar a votación',
              icon: Icons.skip_next_rounded,
              variant: AppButtonVariant.primary,
              onPressed: onSkip,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SecretVotingPhase
// ---------------------------------------------------------------------------

class _SecretVotingPhase extends StatelessWidget {
  const _SecretVotingPhase({
    required this.jugadoresVivos,
    required this.votanteActual,
    required this.mostrandoHandoff,
    required this.votosCount,
    required this.totalVivos,
    required this.onTapCandidato,
    required this.onContinuarHandoff,
    required this.onCambiarAUnanime,
    required this.todosVotaron,
    required this.onRevelar,
  });

  final List<Jugador> jugadoresVivos;
  final Jugador? votanteActual;
  final bool mostrandoHandoff;
  final int votosCount;
  final int totalVivos;
  final void Function(Jugador votante, Jugador candidato) onTapCandidato;
  final VoidCallback onContinuarHandoff;
  final VoidCallback onCambiarAUnanime;
  final bool todosVotaron;
  final VoidCallback onRevelar;

  @override
  Widget build(BuildContext context) {
    if (todosVotaron || votanteActual == null) {
      return Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 74, height: 74, alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.safe.withValues(alpha: 0.12),
                border: Border.all(color: AppColors.safe),
              ),
              child: const Icon(Icons.how_to_vote_rounded,
                  color: AppColors.safe, size: 36),
            ),
            const SizedBox(height: 16),
            const AutoFitTitle('Todos votaron',
                style: AppType.titleL, maxLines: 1),
            const SizedBox(height: 6),
            Text('$votosCount / $totalVivos', style: AppType.bodyS),
            const SizedBox(height: 22),
            AppButton(
              text: 'Revelar resultado',
              icon: Icons.visibility_rounded,
              variant: AppButtonVariant.safe,
              onPressed: onRevelar,
            ),
          ],
        ),
      );
    }

    if (mostrandoHandoff) {
      return Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 74, height: 74, alignment: Alignment.center,
              decoration: const BoxDecoration(
                  color: AppColors.danger, shape: BoxShape.circle),
              child: const Icon(Icons.swap_horiz_rounded,
                  color: Colors.white, size: 38),
            ),
            const SizedBox(height: 14),
            const Text('Voto registrado', style: AppType.bodyS),
            const SizedBox(height: 8),
            AutoFitTitle('Pasa el celular a\n${votanteActual!.nombre}',
                style: AppType.titleL, textAlign: TextAlign.center, maxLines: 2),
            const SizedBox(height: 22),
            AppButton(
              text: 'Estoy listo',
              icon: Icons.visibility_rounded,
              variant: AppButtonVariant.primary,
              onPressed: onContinuarHandoff,
            ),
          ],
        ),
      );
    }

    final candidatos = jugadoresVivos
        .where((j) => j.id != votanteActual!.id)
        .map((j) => AvatarItem(id: j.id, label: j.nombre))
        .toList();

    return Expanded(
      child: Column(
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: AppType.titleL,
              children: [
                const TextSpan(text: 'Vota: ',
                    style: TextStyle(color: AppColors.textSecondary)),
                TextSpan(
                  text: votanteActual!.nombre,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Text('¿Quién es el impostor?', style: AppType.bodyS),
          const SizedBox(height: 8),
          Expanded(
            child: AdaptiveAvatarGrid(
              items: candidatos,
              onTap: (item) {
                final cand = jugadoresVivos.firstWhere((j) => j.id == item.id);
                onTapCandidato(votanteActual!, cand);
              },
            ),
          ),
          TextButton.icon(
            onPressed: onCambiarAUnanime,
            icon: const Icon(Icons.balance_rounded,
                color: AppColors.textSecondary, size: 18),
            label: Text('Votación unánime',
                style: AppType.bodyS.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 4),
          _ProgresoVotos(votosCount: votosCount, totalVivos: totalVivos),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ProgresoVotos
// ---------------------------------------------------------------------------

class _ProgresoVotos extends StatelessWidget {
  const _ProgresoVotos({required this.votosCount, required this.totalVivos});
  final int votosCount;
  final int totalVivos;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 4, runSpacing: 4,
          children: [
            for (var i = 0; i < totalVivos; i++)
              Container(
                width: 16, height: 5,
                decoration: BoxDecoration(
                  color: i < votosCount
                      ? AppColors.safe : AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text('$votosCount / $totalVivos votaron', style: AppType.bodyS),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _UnanimousVotingPhase
// ---------------------------------------------------------------------------

class _UnanimousVotingPhase extends StatelessWidget {
  const _UnanimousVotingPhase({
    required this.jugadoresVivos,
    required this.onTapJugador,
    required this.onCambiarASecreto,
  });

  final List<Jugador> jugadoresVivos;
  final void Function(Jugador) onTapJugador;
  final VoidCallback onCambiarASecreto;

  @override
  Widget build(BuildContext context) {
    final items = jugadoresVivos
        .map((j) => AvatarItem(id: j.id, label: j.nombre))
        .toList();
    return Expanded(
      child: Column(
        children: [
          const AutoFitTitle('Voto unánime', style: AppType.titleL, maxLines: 1),
          const SizedBox(height: 4),
          const Text('Todos votan al mismo si están de acuerdo',
              style: AppType.bodyS, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Expanded(
            child: AdaptiveAvatarGrid(
              items: items,
              onTap: (item) {
                final j = jugadoresVivos.firstWhere((p) => p.id == item.id);
                onTapJugador(j);
              },
            ),
          ),
          TextButton.icon(
            onPressed: onCambiarASecreto,
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppColors.textSecondary, size: 18),
            label: Text('Volver a voto secreto',
                style: AppType.bodyS.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
