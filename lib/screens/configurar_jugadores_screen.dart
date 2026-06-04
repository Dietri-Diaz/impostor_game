// lib/screens/configurar_jugadores_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/app_typography.dart';
import '../core/constants.dart';
import '../core/enums.dart';
import '../core/validators.dart';
import '../models/configuracion_partida.dart';
import '../models/sesion_juego.dart';
import '../services/audio_service.dart';
import '../repositories/historial_jugador_repository.dart';
import '../widgets/app_button.dart';
import '../widgets/app_components.dart';
import 'lobby_screen.dart';

class ConfigurarJugadoresScreen extends StatefulWidget {
  final String tematica;

  const ConfigurarJugadoresScreen({
    super.key,
    required this.tematica,
  });

  @override
  State<ConfigurarJugadoresScreen> createState() =>
      _ConfigurarJugadoresScreenState();
}

class _ConfigurarJugadoresScreenState extends State<ConfigurarJugadoresScreen> {
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];
  final _formKey = GlobalKey<FormState>();
  final HistorialJugadorRepository _historialRepo = HistorialJugadorRepository();
  List<String> _sugerencias = [];

  // Autocompletar dinámico: sugerencias filtradas por índice de jugador.
  final Map<int, List<String>> _sugerenciasFiltradas = {};
  int? _indiceEnfocado;
  Timer? _searchDebounce;

  // Configuración
  TiempoDiscusion _tiempoSeleccionado = TiempoDiscusion.dosMinutos;
  bool _eliminarEnEmpate = false;

  static const int _minJugadores = GameConstants.minPlayers;
  static const int _maxJugadores = GameConstants.maxPlayers;

  @override
  void initState() {
    super.initState();
    // Empezar con 4 jugadores por defecto
    for (int i = 0; i < 4; i++) {
      _addController(i);
    }
    _cargarHistorial();
  }

  void _addController(int index) {
    _controllers.add(TextEditingController(text: 'Jugador ${index + 1}'));
    final focus = FocusNode();
    focus.addListener(() => _onFocusChange(index, focus.hasFocus));
    _focusNodes.add(focus);
  }

  Future<void> _cargarHistorial() async {
    final historial = await _historialRepo.obtenerHistorial();
    if (!mounted) return;
    setState(() {
      _sugerencias = historial.map((h) => h.nombre).toList();
    });
  }

  void _onFocusChange(int index, bool hasFocus) {
    if (hasFocus) {
      setState(() => _indiceEnfocado = index);
      _onNombreChange(index, _controllers[index].text);
    } else {
      // Pequeño delay para permitir que el tap en una sugerencia se procese
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        if (_indiceEnfocado == index && !_focusNodes[index].hasFocus) {
          setState(() => _indiceEnfocado = null);
        }
      });
    }
  }

  void _onNombreChange(int index, String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () async {
      final trimmed = query.trim();
      if (trimmed.isEmpty) {
        if (!mounted) return;
        setState(() => _sugerenciasFiltradas[index] = const []);
        return;
      }
      final resultados = await _historialRepo.buscarNombres(trimmed);
      if (!mounted) return;
      // Ocultar la sugerencia exacta (ya está escrita)
      final filtradas = resultados
          .where((n) => n.toLowerCase() != trimmed.toLowerCase())
          .toList();
      setState(() => _sugerenciasFiltradas[index] = filtradas);
    });
  }

  void _seleccionarSugerencia(int index, String nombre) {
    AudioService.playClick();
    _controllers[index].text = nombre;
    _controllers[index].selection = TextSelection.fromPosition(
      TextPosition(offset: nombre.length),
    );
    setState(() {
      _sugerenciasFiltradas[index] = const [];
      _indiceEnfocado = null;
    });
    _focusNodes[index].unfocus();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _agregarJugador() {
    if (_controllers.length >= _maxJugadores) return;
    setState(() {
      _addController(_controllers.length);
    });
  }

  void _quitarJugador() {
    if (_controllers.length <= _minJugadores) return;
    setState(() {
      _controllers.last.dispose();
      _controllers.removeLast();
      _focusNodes.last.dispose();
      _focusNodes.removeLast();
      _sugerenciasFiltradas.remove(_controllers.length);
    });
  }

  void _mostrarSugerencias(int index) {
    if (_sugerencias.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return AppSheet(
          maxHeight: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Nombres recientes', style: AppType.titleL),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _sugerencias.length,
                  itemBuilder: (context, i) {
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            AppColors.danger.withValues(alpha: 0.15),
                        child: const Icon(Icons.person,
                            color: AppColors.danger, size: 20),
                      ),
                      title: Text(_sugerencias[i],
                          style: TextStyle(color: AppTheme.textPrimary)),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline,
                            color: AppTheme.textMuted, size: 20),
                        onPressed: () async {
                          await _historialRepo
                              .eliminarNombre(_sugerencias[i]);
                          if (!context.mounted) return;
                          _cargarHistorial();
                          Navigator.pop(context);
                          _mostrarSugerencias(index);
                        },
                      ),
                      onTap: () {
                        _controllers[index].text = _sugerencias[i];
                        Navigator.pop(context);
                      },
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

  void _mostrarConfiguracion() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AppSheet(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.settings_rounded,
                              color: AppColors.primary),
                          SizedBox(width: 10),
                          Text('Configuración', style: AppType.titleL),
                        ],
                      ),
                      const SizedBox(height: 25),

                      // Tiempo de discusión
                      AppCard(
                        child: Column(
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.timer_rounded,
                                    color: AppColors.primary, size: 22),
                                SizedBox(width: 8),
                                Text('Tiempo de discusión',
                                    style: AppType.titleM),
                              ],
                            ),
                            const SizedBox(height: 15),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              alignment: WrapAlignment.center,
                              children:
                                  TiempoDiscusion.values.map((tiempo) {
                                final isSelected =
                                    tiempo == _tiempoSeleccionado;
                                return GestureDetector(
                                  onTap: () {
                                    AudioService.playClick();
                                    setModalState(() =>
                                        _tiempoSeleccionado = tiempo);
                                    setState(() {});
                                  },
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.danger
                                          : AppColors.surface,
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.danger
                                            : AppColors.border,
                                      ),
                                    ),
                                    child: Text(
                                      tiempo.nombre,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 14,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Eliminar en empate
                      GestureDetector(
                        onTap: () {
                          AudioService.playClick();
                          setModalState(
                              () => _eliminarEnEmpate = !_eliminarEnEmpate);
                          setState(() {});
                        },
                        child: AppCard(
                          borderColor: _eliminarEnEmpate
                              ? AppColors.danger.withValues(alpha: 0.5)
                              : null,
                          child: Row(
                            children: [
                              Icon(
                                _eliminarEnEmpate
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color: _eliminarEnEmpate
                                    ? AppColors.danger
                                    : AppTheme.textMuted,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Text('Eliminar en caso de empate',
                                        style: AppType.titleM),
                                    const SizedBox(height: 4),
                                    Text(
                                      _eliminarEnEmpate
                                          ? 'Se eliminará alguien aleatoriamente'
                                          : 'Nadie será eliminado',
                                      style: AppType.bodyS,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),

                      AppButton(
                        text: 'Listo',
                        icon: Icons.check_rounded,
                        onPressed: () {
                          AudioService.playClick();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _iniciarPartida() {
    if (!_formKey.currentState!.validate()) return;

    AudioService.playClick();

    final nombres = _controllers.map((c) => c.text.trim()).toList();
    final listError = Validators.playerList(nombres);
    if (listError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(listError),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    unawaited(_historialRepo.guardarNombres(nombres));

    final configuracion = ConfiguracionPartida(
      tiempoDiscusion: _tiempoSeleccionado,
      eliminarEnEmpate: _eliminarEnEmpate,
    );

    final sesion = SesionJuego(
      tematica: widget.tematica,
      nombresJugadores: nombres,
      configuracion: configuracion,
    );

    Navigator.push(
      context,
      FadeScalePageRoute(page: LobbyScreen(sesion: sesion)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  AppHeader(
                    title: 'Configurar Partida',
                    onBack: () {
                      AudioService.playClick();
                      Navigator.pop(context);
                    },
                    actions: [
                      IconButton(
                        icon: Icon(Icons.settings_rounded,
                            color: AppTheme.textPrimary),
                        onPressed: _mostrarConfiguracion,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Jugadores counter + add/remove
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.people_rounded,
                            color: AppColors.primary, size: 22),
                        const SizedBox(width: 10),
                        Text('Jugadores: ${_controllers.length}',
                            style: AppType.titleM),
                        const Spacer(),
                        // Quitar — surface + border, danger tint cuando activo
                        GestureDetector(
                          onTap: _quitarJugador,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _controllers.length > _minJugadores
                                    ? AppColors.danger
                                        .withValues(alpha: 0.6)
                                    : AppColors.border,
                              ),
                            ),
                            child: Icon(
                              Icons.remove_rounded,
                              color: _controllers.length > _minJugadores
                                  ? AppColors.danger
                                  : AppColors.textMuted,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Agregar — surface + border, safe tint cuando activo
                        GestureDetector(
                          onTap: _agregarJugador,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _controllers.length < _maxJugadores
                                    ? AppColors.safe.withValues(alpha: 0.6)
                                    : AppColors.border,
                              ),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              color: _controllers.length < _maxJugadores
                                  ? AppColors.safe
                                  : AppColors.textMuted,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Info
                  if (_sugerencias.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Toca el reloj para ver nombres recientes',
                        style: AppType.bodyS,
                      ),
                    ),

                  // Lista de jugadores
                  Expanded(
                    child: ListView.builder(
                      itemCount: _controllers.length,
                      itemBuilder: (context, index) {
                        final sugerencias =
                            _sugerenciasFiltradas[index] ?? const [];
                        final mostrarPanel = _indiceEnfocado == index &&
                            sugerencias.isNotEmpty;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AppCard(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.all(8),
                                      child: CircleAvatar(
                                        radius: 20,
                                        backgroundColor: AppColors.danger,
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _controllers[index],
                                        focusNode: _focusNodes[index],
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.textPrimary,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Jugador ${index + 1}',
                                          hintStyle: TextStyle(
                                              color: AppTheme.textMuted),
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          errorBorder: InputBorder.none,
                                          focusedErrorBorder:
                                              InputBorder.none,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 14),
                                          errorStyle: const TextStyle(
                                            fontSize: 11,
                                            height: 0.5,
                                            color: AppColors.danger,
                                          ),
                                        ),
                                        onTap: () {
                                          _controllers[index].selection =
                                              TextSelection(
                                            baseOffset: 0,
                                            extentOffset:
                                                _controllers[index]
                                                    .text
                                                    .length,
                                          );
                                        },
                                        onChanged: (v) =>
                                            _onNombreChange(index, v),
                                        validator: Validators.playerName,
                                      ),
                                    ),
                                    if (_sugerencias.isNotEmpty)
                                      IconButton(
                                        icon: Icon(Icons.history_rounded,
                                            color: AppTheme.textMuted,
                                            size: 20),
                                        onPressed: () =>
                                            _mostrarSugerencias(index),
                                      ),
                                    const SizedBox(width: 4),
                                  ],
                                ),
                              ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOut,
                                child: mostrarPanel
                                    ? _SugerenciasPanel(
                                        sugerencias: sugerencias,
                                        onSeleccionar: (n) =>
                                            _seleccionarSugerencia(
                                                index, n),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Config summary
                  GestureDetector(
                    onTap: _mostrarConfiguracion,
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.timer_rounded,
                              color: AppColors.accentAlt, size: 20),
                          const SizedBox(width: 8),
                          Text(_tiempoSeleccionado.nombre,
                              style: AppType.body_
                                  .copyWith(fontSize: 14)),
                          const SizedBox(width: 16),
                          const Icon(Icons.balance_rounded,
                              color: AppColors.purple, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _eliminarEnEmpate
                                ? 'Eliminar en empate'
                                : 'No eliminar en empate',
                            style:
                                AppType.body_.copyWith(fontSize: 14),
                          ),
                          const Spacer(),
                          Icon(Icons.edit_rounded,
                              color: AppTheme.textMuted, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  AppButton(
                    text: 'Iniciar partida',
                    icon: Icons.play_arrow_rounded,
                    onPressed: _iniciarPartida,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SugerenciasPanel extends StatelessWidget {
  const _SugerenciasPanel({
    required this.sugerencias,
    required this.onSeleccionar,
  });

  final List<String> sugerencias;
  final void Function(String) onSeleccionar;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: sugerencias.map((nombre) {
          return InkWell(
            onTap: () => onSeleccionar(nombre),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded,
                      size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      nombre,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(Icons.north_west_rounded,
                      size: 14, color: AppColors.textMuted),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
