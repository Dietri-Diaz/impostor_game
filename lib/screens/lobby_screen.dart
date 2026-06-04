// lib/screens/lobby_screen.dart

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/app_typography.dart';
import '../core/constants.dart';
import '../core/validators.dart';
import '../data/tematicas_data.dart';
import '../managers/partida_manager.dart';
import '../models/sesion_juego.dart';
import '../repositories/historial_jugador_repository.dart';
import '../repositories/tematica_repository.dart';
import '../services/audio_service.dart';
import '../services/preferences_service.dart';
import '../services/session_persistence.dart';
import '../widgets/app_button.dart';
import '../widgets/app_components.dart';
import '../widgets/auto_fit_title.dart';
import 'home_screen.dart';
import 'reglas_screen.dart';
import 'resultado_final_screen.dart';
import 'revelar_roles_screen.dart';

/// Wrapper externo que provee `SesionJuego` y `PartidaManager` al subárbol.
/// Antes se pasaban como argumentos a cada pantalla descendente; ahora la
/// sesión vive en el contexto y `LobbyScreen` se rebuildea automáticamente
/// cuando `SesionJuego` notifica cambios.
class LobbyScreen extends StatelessWidget {
  const LobbyScreen({super.key, required this.sesion});

  final SesionJuego sesion;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SesionJuego>.value(value: sesion),
        ChangeNotifierProvider<PartidaManager>(
          create: (_) => PartidaManager(),
        ),
      ],
      child: const _LobbyView(),
    );
  }
}

class _OpcionTematica {
  const _OpcionTematica({
    required this.nombre,
    required this.cantidad,
    required this.custom,
  });
  final String nombre;
  final int cantidad;
  final bool custom;
}

class _LobbyView extends StatefulWidget {
  const _LobbyView();

  @override
  State<_LobbyView> createState() => _LobbyViewState();
}

class _LobbyViewState extends State<_LobbyView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  final HistorialJugadorRepository _historialRepo = HistorialJugadorRepository();
  SessionPersistence? _persistence;
  bool _showHistorial = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
    final sesion = context.read<SesionJuego>();
    sesion.inicializarPuntuacion();
    // Auto-guardar la sesión cuando notifique. Snapshot inicial inmediato
    // para que aunque la app se cierre antes del primer cambio, exista
    // algo que restaurar.
    _persistence = SessionPersistence(
      prefs: context.read<PreferencesService>(),
      sesion: sesion,
    );
    _persistence!.saveNow();
  }

  @override
  void dispose() {
    _animController.dispose();
    _persistence?.dispose();
    super.dispose();
  }

  Future<List<String>> _obtenerPersonajes(String tematica) async {
    if (tematicasData.containsKey(tematica)) {
      return tematicasData[tematica]!.map((p) => p.nombre).toList();
    }
    final repo = TematicaRepository();
    final personalizadas = await repo.obtenerTematicas();
    final t = personalizadas.firstWhere((t) => t.nombre == tematica);
    return t.personajes;
  }

  Future<void> _iniciarRonda() async {
    AudioService.playReveal();

    // Capturamos las refs antes de cualquier await para no usar
    // context cross-async.
    final sesion = context.read<SesionJuego>();
    final manager = context.read<PartidaManager>();
    final navigator = Navigator.of(context);

    final personajes = await _obtenerPersonajes(sesion.tematica);
    final personajeSecreto = personajes[Random().nextInt(personajes.length)];

    final partida = manager.crearPartida(
      tematica: sesion.tematica,
      personajeSecreto: personajeSecreto,
      nombresJugadores: sesion.nombresJugadores,
      configuracion: sesion.configuracion,
    );

    unawaited(_historialRepo.guardarNombres(sesion.nombresJugadores));

    if (!mounted) return;

    await navigator.push(
      FadeScalePageRoute(
        page: RevelarRolesScreen(
          partida: partida,
          partidaManager: manager,
          sesion: sesion,
        ),
      ),
    );
    // Al volver, sesion/manager ya notificaron cambios — el watch en build
    // del view re-renderiza solo. No hace falta setState manual.
  }

  void _mostrarResumenSesion() {
    setState(() => _showHistorial = !_showHistorial);
  }

  Future<void> _cambiarTematica() async {
    final tematicas = <_OpcionTematica>[
      for (final nombre in tematicasData.keys)
        _OpcionTematica(
          nombre: nombre,
          cantidad: tematicasData[nombre]!.length,
          custom: false,
        ),
    ];

    try {
      final personalizadas = await TematicaRepository().obtenerTematicas();
      for (final t in personalizadas) {
        tematicas.add(_OpcionTematica(
          nombre: t.nombre,
          cantidad: t.personajes.length,
          custom: true,
        ));
      }
    } catch (e, st) {
      // No bloqueamos el flujo: si fallan las personalizadas seguimos con
      // las predefinidas, pero dejamos rastro en el log.
      debugPrint('[Lobby] cargar tematicas personalizadas fallo: $e\n$st');
    }

    if (!mounted) return;

    final sesion = context.read<SesionJuego>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return AppSheet(
          maxHeight: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('Cambiar Temática', style: AppType.titleL),
              ),
              Text(
                'Temática actual: ${sesion.tematica}',
                style: AppType.bodyS,
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: tematicas.length,
                  itemBuilder: (context, index) {
                    final t = tematicas[index];
                    final nombre = t.nombre;
                    final cantidad = t.cantidad;
                    final isCustom = t.custom;
                    final isActual = nombre == sesion.tematica;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        selected: isActual,
                        borderColor: isActual
                            ? AppColors.danger.withValues(alpha: 0.6)
                            : null,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        onTap: () {
                          sesion.tematica = nombre;
                          AudioService.playClick();
                          Navigator.pop(sheetCtx);
                        },
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isActual
                                    ? AppColors.danger.withValues(alpha: 0.15)
                                    : AppColors.surfaceHigh,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isActual
                                    ? Icons.check_circle_rounded
                                    : Icons.category_rounded,
                                color: isActual
                                    ? AppColors.danger
                                    : AppColors.textSecondary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nombre,
                                    style: AppType.titleM.copyWith(
                                      color: isActual
                                          ? AppColors.textPrimary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '$cantidad personajes'
                                    '${isCustom ? ' · Custom' : ''}',
                                    style: AppType.bodyS,
                                  ),
                                ],
                              ),
                            ),
                            if (isActual)
                              const Icon(
                                Icons.check_rounded,
                                color: AppColors.danger,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Máximo de impostores razonable: civiles deben superar en número.
  int _maxImpostores(int numJugadores) =>
      ((numJugadores - 1) / 2).floor().clamp(1, numJugadores - 1);

  void _cambiarNumeroImpostores(int delta) {
    final sesion = context.read<SesionJuego>();
    final actual = sesion.configuracion.numeroImpostores;
    final maxImp = _maxImpostores(sesion.nombresJugadores.length);
    final nuevo =
        (actual + delta).clamp(GameConstants.minImpostors, maxImp);
    if (nuevo == actual) return;
    AudioService.playClick();
    sesion.configuracion =
        sesion.configuracion.copyWith(numeroImpostores: nuevo);
  }

  void _mostrarEditarJugadores() {
    final sesion = context.read<SesionJuego>();
    Navigator.push<void>(
      context,
      SlidePageRoute<void>(
        page: _EditarJugadoresPage(
          nombresIniciales: List.of(sesion.nombresJugadores),
          // El setter de SesionJuego notifica a los listeners, así que el
          // watch en build se encarga del rebuild.
          onGuardar: (nuevosNombres) =>
              sesion.nombresJugadores = nuevosNombres,
        ),
      ),
    );
  }

  void _salirAlInicio() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.home_rounded, color: AppColors.danger),
            const SizedBox(width: 10),
            Text('Volver al inicio', style: AppTheme.titleLarge),
          ],
        ),
        content: Text(
          'Tu partida quedará guardada. Podrás continuarla desde el inicio con "Continuar".',
          style: AppTheme.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              // Volvemos al inicio SIN borrar la sesión: queda guardada y
              // aparece "Continuar". Solo se sobrescribe al iniciar una
              // partida nueva completa.
              Navigator.pushAndRemoveUntil(
                context,
                FadeScalePageRoute(page: const HomeScreen()),
                (route) => false,
              );
            },
            child: const Text('Volver al inicio',
                style: TextStyle(
                    color: AppColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<SesionJuego>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _salirAlInicio();
      },
      child: Scaffold(
        body: GradientBackground(
          child: SafeArea(
            child: Column(
              children: [
                // Header
                AppHeader(
                  title: 'Sala de Juego',
                  onBack: _salirAlInicio,
                  actions: [
                    IconButton(
                      icon: Icon(Icons.help_outline_rounded,
                          color: AppTheme.textPrimary),
                      onPressed: () {
                        AudioService.playClick();
                        Navigator.push(
                          context,
                          SlidePageRoute(page: const ReglasScreen()),
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.edit_rounded,
                          color: AppTheme.textPrimary),
                      onPressed: _mostrarEditarJugadores,
                    ),
                    IconButton(
                      icon: Icon(
                        _showHistorial
                            ? Icons.close_rounded
                            : Icons.history_rounded,
                        color: AppTheme.textPrimary,
                      ),
                      onPressed: _mostrarResumenSesion,
                    ),
                  ],
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Temática actual — toca para cambiar
                        AppCard(
                          onTap: _cambiarTematica,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.danger
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.category_rounded,
                                    color: AppColors.danger, size: 24),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    AutoFitTitle(
                                      sesion.tematica,
                                      style: AppType.titleL,
                                      textAlign: TextAlign.left,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${sesion.nombresJugadores.length} jugadores · ${sesion.rondasJugadas} rondas jugadas',
                                      style: AppType.bodyS,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.swap_horiz_rounded,
                                  color: AppTheme.textMuted, size: 22),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Selector de número de impostores
                        _SelectorImpostores(
                          numImpostores:
                              sesion.configuracion.numeroImpostores,
                          maxImpostores:
                              _maxImpostores(sesion.nombresJugadores.length),
                          onIncrementar: () =>
                              _cambiarNumeroImpostores(1),
                          onDecrementar: () =>
                              _cambiarNumeroImpostores(-1),
                        ),

                        const SizedBox(height: 16),

                        // Historial de rondas (si está visible)
                        if (_showHistorial &&
                            sesion.historialRondas.isNotEmpty) ...[
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Historial de Rondas',
                                style: AppType.titleL),
                          ),
                          const SizedBox(height: 12),
                          ...sesion.historialRondas.map((r) {
                            final ganaron = r.ganador == 'jugadores';
                            final accentColor = ganaron
                                ? AppColors.safe
                                : AppColors.danger;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: AppCard(
                                borderColor:
                                    accentColor.withValues(alpha: 0.35),
                                padding: EdgeInsets.zero,
                                child: IntrinsicHeight(
                                  child: Row(
                                    children: [
                                      // Acento lateral de color
                                      Container(
                                        width: 4,
                                        decoration: BoxDecoration(
                                          color: accentColor,
                                          borderRadius:
                                              const BorderRadius.only(
                                            topLeft: Radius.circular(18),
                                            bottomLeft:
                                                Radius.circular(18),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 14),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 18,
                                                backgroundColor: accentColor
                                                    .withValues(alpha: 0.15),
                                                child: Text(
                                                  '${r.numeroRonda}',
                                                  style:
                                                      AppType.titleM.copyWith(
                                                    color: accentColor,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .start,
                                                  children: [
                                                    Text(
                                                      ganaron
                                                          ? 'Civiles ganaron'
                                                          : 'Impostor ganó',
                                                      style:
                                                          AppType.titleM,
                                                    ),
                                                    const SizedBox(
                                                        height: 2),
                                                    Text(
                                                      'Impostor: ${r.impostorNombre} · Personaje: ${r.personajeSecreto}',
                                                      style: AppType.bodyS,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 16),
                        ],

                        // Scoreboard
                        if (sesion.rondasJugadas > 0) ...[
                          AppCard(
                            child: Column(
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.emoji_events_rounded,
                                        color: AppColors.gold, size: 24),
                                    SizedBox(width: 10),
                                    Text('Puntuación',
                                        style: AppType.titleL),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ...sesion.rankingOrdenado
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                  final index = entry.key;
                                  final jugador = entry.value;
                                  final isFirst = index == 0;
                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isFirst
                                            ? AppColors.gold
                                                .withValues(alpha: 0.08)
                                            : AppColors.surfaceHigh,
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isFirst
                                              ? AppColors.gold
                                                  .withValues(alpha: 0.4)
                                              : AppColors.border,
                                          width: isFirst ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            '${index + 1}.',
                                            style: AppType.titleM.copyWith(
                                              color: isFirst
                                                  ? AppColors.gold
                                                  : AppColors.textMuted,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              jugador.key,
                                              style: AppType.titleM.copyWith(
                                                color:
                                                    AppColors.textPrimary,
                                                fontWeight: isFirst
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isFirst
                                                  ? AppColors.gold
                                                  : AppColors.surfaceHigh,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: isFirst
                                                  ? null
                                                  : Border.all(
                                                      color: AppColors
                                                          .border),
                                            ),
                                            child: Text(
                                              '${jugador.value} pts',
                                              style:
                                                  AppType.label.copyWith(
                                                color: isFirst
                                                    ? AppColors.ink
                                                    : AppColors
                                                        .textSecondary,
                                                fontSize: 12,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Jugadores actuales
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.people_rounded,
                                      color: AppColors.safe, size: 24),
                                  SizedBox(width: 10),
                                  Text('Jugadores',
                                      style: AppType.titleL),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: sesion.nombresJugadores
                                    .map((nombre) => AppChip(
                                          label: nombre,
                                          color: AppColors.safe,
                                        ))
                                    .toList(),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Botón iniciar ronda
                        AppButton(
                          text: sesion.rondasJugadas == 0
                              ? 'INICIAR PRIMERA RONDA'
                              : 'NUEVA RONDA',
                          icon: Icons.play_arrow_rounded,
                          variant: AppButtonVariant.primary,
                          onPressed: _iniciarRonda,
                        ),

                        if (sesion.rondasJugadas > 0) ...[
                          const SizedBox(height: 16),
                          AppButton(
                            text: 'VER RESULTADO FINAL',
                            icon: Icons.emoji_events_rounded,
                            variant: AppButtonVariant.safe,
                            onPressed: () {
                              final manager =
                                  context.read<PartidaManager>();
                              final partida = manager.partidaActual;
                              if (partida == null) return;
                              Navigator.push<void>(
                                context,
                                FadeScalePageRoute<void>(
                                  page: ResultadoFinalScreen(
                                    partida: partida,
                                    partidaManager: manager,
                                    sesion: sesion,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditarJugadoresPage extends StatefulWidget {
  final List<String> nombresIniciales;
  final void Function(List<String>) onGuardar;

  const _EditarJugadoresPage({
    required this.nombresIniciales,
    required this.onGuardar,
  });

  @override
  State<_EditarJugadoresPage> createState() => _EditarJugadoresPageState();
}

class _EditarJugadoresPageState extends State<_EditarJugadoresPage> {
  final List<TextEditingController> _controllers = [];

  @override
  void initState() {
    super.initState();
    for (var nombre in widget.nombresIniciales) {
      _controllers.add(TextEditingController(text: nombre));
    }
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _agregar() {
    if (_controllers.length >= GameConstants.maxPlayers) return;
    setState(() {
      _controllers.add(
        TextEditingController(text: 'Jugador ${_controllers.length + 1}'),
      );
    });
  }

  void _quitar() {
    if (_controllers.length <= GameConstants.minPlayers) return;
    setState(() {
      _controllers.last.dispose();
      _controllers.removeLast();
    });
  }

  void _guardar() {
    final nombres = _controllers.map((c) => c.text.trim()).toList();
    final error = Validators.playerList(nombres);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    widget.onGuardar(nombres);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                AppHeader(
                  title: 'Editar Jugadores',
                  onBack: () => Navigator.pop(context),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: _controllers.length,
                    itemBuilder: (context, i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.danger,
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _controllers[i],
                                  style: TextStyle(
                                      color: AppTheme.textPrimary),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    hintText: 'Jugador ${i + 1}',
                                    hintStyle: TextStyle(
                                        color: AppTheme.textMuted),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (_controllers.length > GameConstants.minPlayers)
                      Expanded(
                        child: AppButton(
                          text: 'Quitar',
                          icon: Icons.remove_circle_rounded,
                          variant: AppButtonVariant.secondary,
                          onPressed: _quitar,
                        ),
                      ),
                    if (_controllers.length > GameConstants.minPlayers &&
                        _controllers.length < GameConstants.maxPlayers)
                      const SizedBox(width: 10),
                    if (_controllers.length < GameConstants.maxPlayers)
                      Expanded(
                        child: AppButton(
                          text: 'Agregar',
                          icon: Icons.add_circle_rounded,
                          variant: AppButtonVariant.secondary,
                          onPressed: _agregar,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                AppButton(
                  text: 'GUARDAR CAMBIOS',
                  icon: Icons.check_rounded,
                  variant: AppButtonVariant.primary,
                  onPressed: _guardar,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectorImpostores extends StatelessWidget {
  const _SelectorImpostores({
    required this.numImpostores,
    required this.maxImpostores,
    required this.onIncrementar,
    required this.onDecrementar,
  });

  final int numImpostores;
  final int maxImpostores;
  final VoidCallback onIncrementar;
  final VoidCallback onDecrementar;

  @override
  Widget build(BuildContext context) {
    final puedeRestar = numImpostores > GameConstants.minImpostors;
    final puedeSumar = numImpostores < maxImpostores;
    return AppCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.theater_comedy_rounded,
                color: AppColors.danger, size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  numImpostores == 1
                      ? '1 Impostor'
                      : '$numImpostores Impostores',
                  style: AppType.titleM,
                ),
                const SizedBox(height: 2),
                Text(
                  'Máx. $maxImpostores con esta cantidad de jugadores',
                  style: AppType.bodyS,
                ),
              ],
            ),
          ),
          _StepperButton(
            icon: Icons.remove_rounded,
            activeColor: AppColors.danger,
            enabled: puedeRestar,
            onTap: puedeRestar ? onDecrementar : null,
          ),
          const SizedBox(width: 8),
          _StepperButton(
            icon: Icons.add_rounded,
            activeColor: AppColors.safe,
            enabled: puedeSumar,
            onTap: puedeSumar ? onIncrementar : null,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.activeColor,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final Color activeColor;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: enabled
              ? activeColor.withValues(alpha: 0.12)
              : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled
                ? activeColor.withValues(alpha: 0.4)
                : AppColors.border,
          ),
        ),
        child: Icon(
          icon,
          color: enabled ? activeColor : AppColors.textMuted,
          size: 20,
        ),
      ),
    );
  }
}
