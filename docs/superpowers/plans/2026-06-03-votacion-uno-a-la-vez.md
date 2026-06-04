# Rediseño de la Votación "Un votante a la vez" — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development o superpowers:executing-plans para ejecutar tarea por tarea. Los pasos usan checkbox (`- [ ]`).

**Goal:** Reemplazar la fase de voto secreto (lista con scroll) por un flujo "un votante a la vez" con una rejilla de caras **simétrica y adaptativa** (sin scroll ni espacio sobrante, caras nunca gigantes), conservando el **voto unánime** y toda la lógica de conteo/empate/eliminación.

**Architecture:** Se añade un widget reutilizable `AdaptiveAvatarGrid` (en `lib/widgets/`) con una función pura `computeAvatarLayout` que calcula columnas + tamaño de cara para llenar el área disponible de forma simétrica (lo más cuadrada posible), centrando la última fila y con tope de tamaño. La pantalla `votacion_screen.dart` se reescribe en sus fases de voto (secreto = un votante a la vez con la rejilla; unánime = misma rejilla en modo selección única). La lógica de juego (`procesarVotacion`, `obtenerJugadorEliminado`, `_revelarResultado`, `verificarFinDeJuego`, `PopScope`, temporizador `ValueNotifier`, fase de discusión con "Empieza: X") NO cambia.

**Tech Stack:** Flutter/Dart, design system Minimal Bold (AppColors/AppType/AppButton), `flutter_test`.

**Spec base:** validado vía mockups (Opción A simétrica + unánime conservado; botón unánime = secundario contorno on-tone).

---

## Mapa de archivos

**Crear:**
- `lib/widgets/adaptive_avatar_grid.dart` — `AvatarItem`, `GridLayout`, `computeAvatarLayout(...)`, `AdaptiveAvatarGrid` (widget).
- `test/adaptive_avatar_grid_test.dart` — tests de `computeAvatarLayout`.

**Modificar:**
- `lib/screens/votacion_screen.dart` — reescribir `_SecretVotingPhase` (un votante a la vez) y `_UnanimousVotingPhase` (misma rejilla, selección única). Añadir estado de "handoff" entre votantes en `_VotacionScreenState`.

**Sin cambios:** `partida_manager.dart`, modelos, demás pantallas.

---

## Paleta y reglas (recordatorio)
- Caras: `AppColors.surfaceHigh` + borde `AppColors.border`, inicial en blanco. Seleccionada/objetivo: `AppColors.danger`.
- Botón "⚖️ Votación unánime": **secundario contorno** → `AppButton(variant: AppButtonVariant.secondary)` o un contenedor transparente con borde `AppColors.border` y texto `AppColors.textSecondary`. (Alternativas B: superficie `surfaceHigh`; C: solo texto `textSecondary` — cambio trivial.)
- "Revelar resultado" / confirmar: `AppButton(variant: safe)`.
- Texto en español; títulos grandes con `AutoFitTitle`.

## Actualización de diseño (final, validada con prototipo)
- **Confirmación con hoja inferior (no toque directo):** al tocar un candidato (secreto) o un jugador (unánime) se abre `showModalBottomSheet` (fondo `AppColors.surface`, esquinas superiores redondeadas 24, `barrierColor` negro ~0.45). Contenido = **fila**: círculo rojo (`AppColors.danger`) de 48px con la inicial + columna con título (bold 17) y subtítulo (muted 12):
  - Secreto → título `¿Votar por {nombre}?`, subtítulo `Tu voto es secreto.`, botones `[Cancelar]` (secundario contorno) y `[Votar]` (`AppButton danger`, icon `Icons.how_to_vote_rounded`).
  - Unánime → título `¿Eliminar a {nombre}?`, subtítulo `Voto unánime de todos.`, botones `[Cancelar]` y `[Eliminar]` (danger, mismo icon).
  - "Votar"/"Eliminar" cierra la hoja y ejecuta el voto/eliminación; "Cancelar" solo cierra. **Sin** línea de "toque accidental".
  - La hoja modal anima nativa y suave (sin re-render ni hueco; el problema del prototipo HTML no aplica en Flutter). El scrim atenúa la rejilla detrás (las caras siguen visibles).
- **Handoff "pasa el celular":** círculo `AppColors.danger` con `Icons.swap_horiz` (NO emoji) + texto muted "Voto registrado" + `AutoFitTitle('Pasa el celular a\n{siguiente}')` + `AppButton('Estoy listo', icon: Icons.visibility_rounded, variant: primary)`.
- Esto **reemplaza** el enfoque "tap = voto directo" descrito en el V3 de abajo: el tap ahora abre la hoja de confirmación, y el voto se registra al confirmar.

---

## Task V1: función pura `computeAvatarLayout` (+ tipos) con TDD

**Files:**
- Create: `lib/widgets/adaptive_avatar_grid.dart`
- Test: `test/adaptive_avatar_grid_test.dart`

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/adaptive_avatar_grid_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:impostor_game/widgets/adaptive_avatar_grid.dart';

void main() {
  group('computeAvatarLayout', () {
    test('4 caras en área tipo retrato → 2 columnas (2x2 simétrico)', () {
      final l = computeAvatarLayout(
          count: 4, maxWidth: 160, maxHeight: 240);
      expect(l.columns, 2);
      expect(l.cell, greaterThan(0));
    });

    test('1 cara → 1 columna', () {
      final l = computeAvatarLayout(
          count: 1, maxWidth: 160, maxHeight: 240);
      expect(l.columns, 1);
    });

    test('tope de tamaño: con pocas caras la celda no supera maxCell', () {
      final l = computeAvatarLayout(
          count: 2, maxWidth: 400, maxHeight: 400, maxCell: 72);
      expect(l.cell, lessThanOrEqualTo(72));
    });

    test('muchas caras caben: 11 en retrato dan celda > 0 y columnas >= 3',
        () {
      final l = computeAvatarLayout(
          count: 11, maxWidth: 160, maxHeight: 240);
      expect(l.columns, greaterThanOrEqualTo(3));
      expect(l.cell, greaterThan(0));
    });

    test('count 0 no rompe', () {
      final l = computeAvatarLayout(
          count: 0, maxWidth: 160, maxHeight: 240);
      expect(l.cell, 0);
    });
  });
}
```

- [ ] **Step 2: Ejecutar para ver que falla**

Run: `flutter test test/adaptive_avatar_grid_test.dart`
Expected: FAIL (URI 'adaptive_avatar_grid.dart' no existe).

- [ ] **Step 3: Implementar tipos + función pura**

```dart
// lib/widgets/adaptive_avatar_grid.dart
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_typography.dart';

/// Un elemento (jugador) a mostrar como cara en la rejilla.
class AvatarItem {
  const AvatarItem({required this.id, required this.label, this.color});
  final String id;
  final String label;
  final Color? color;
}

/// Columnas + tamaño de celda (cara) elegidos para llenar el área.
class GridLayout {
  const GridLayout(this.columns, this.cell);
  final int columns;
  final double cell;
}

/// Elige columnas y tamaño de cara para que [count] caras llenen el área
/// [maxWidth]x[maxHeight] de la forma más simétrica posible (maximiza el
/// tamaño de la cara que cabe en ambos ejes), sin superar [maxCell]. Las
/// filas parciales se centran en el widget, así que el resultado se ve
/// equilibrado y sin huecos a un lado.
GridLayout computeAvatarLayout({
  required int count,
  required double maxWidth,
  required double maxHeight,
  double spacing = 10,
  double maxCell = 72,
  double labelHeight = 16,
}) {
  if (count <= 0 || maxWidth <= 0 || maxHeight <= 0) {
    return const GridLayout(1, 0);
  }
  var bestCols = 1;
  var bestCell = 0.0;
  for (var cols = 1; cols <= count; cols++) {
    final rows = (count / cols).ceil();
    final cellW = (maxWidth - spacing * (cols - 1)) / cols;
    final cellH = (maxHeight - spacing * (rows - 1)) / rows - labelHeight;
    final cell = cellW < cellH ? cellW : cellH;
    if (cell > bestCell) {
      bestCell = cell;
      bestCols = cols;
    }
  }
  if (bestCell < 0) bestCell = 0;
  if (bestCell > maxCell) bestCell = maxCell;
  return GridLayout(bestCols, bestCell);
}
```

- [ ] **Step 4: Ejecutar para ver que pasa**

Run: `flutter test test/adaptive_avatar_grid_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/adaptive_avatar_grid.dart test/adaptive_avatar_grid_test.dart
git commit -m "feat(ui): computeAvatarLayout simétrico/adaptativo (+test)"
```

## Task V2: widget `AdaptiveAvatarGrid`

**Files:**
- Modify: `lib/widgets/adaptive_avatar_grid.dart` (añadir el widget al final)

- [ ] **Step 1: Añadir el widget**

```dart
/// Rejilla de caras que se adapta al espacio: usa [computeAvatarLayout] para
/// elegir columnas y tamaño, y centra cada fila (incluida la última) para que
/// no queden huecos a un lado. Llama [onTap] al tocar una cara.
class AdaptiveAvatarGrid extends StatelessWidget {
  const AdaptiveAvatarGrid({
    super.key,
    required this.items,
    required this.onTap,
    this.selectedId,
    this.spacing = 10,
    this.maxCell = 72,
  });

  final List<AvatarItem> items;
  final void Function(AvatarItem) onTap;
  final String? selectedId;
  final double spacing;
  final double maxCell;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = computeAvatarLayout(
          count: items.length,
          maxWidth: constraints.maxWidth,
          maxHeight: constraints.maxHeight,
          spacing: spacing,
          maxCell: maxCell,
        );
        final cols = layout.columns;
        final cell = layout.cell;

        // Partir en filas de [cols] elementos.
        final rows = <List<AvatarItem>>[];
        for (var i = 0; i < items.length; i += cols) {
          rows.add(items.sublist(
              i, (i + cols > items.length) ? items.length : i + cols));
        }

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final row in rows)
                Padding(
                  padding: EdgeInsets.only(bottom: spacing),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final item in row)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: spacing / 2),
                          child: _AvatarCell(
                            item: item,
                            size: cell,
                            selected: item.id == selectedId,
                            onTap: () => onTap(item),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AvatarCell extends StatelessWidget {
  const _AvatarCell({
    required this.item,
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final AvatarItem item;
  final double size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = item.color ?? AppColors.danger;
    final inicial = item.label.isNotEmpty ? item.label[0].toUpperCase() : '?';
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? accent : AppColors.surfaceHigh,
                border: Border.all(
                  color: selected ? accent : AppColors.border,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Text(
                inicial,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: size * 0.38,
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: size + 8,
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppType.bodyS.copyWith(
                  color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verificar**

Run: `flutter analyze lib/widgets/adaptive_avatar_grid.dart`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/adaptive_avatar_grid.dart
git commit -m "feat(ui): widget AdaptiveAvatarGrid (rejilla simétrica centrada)"
```

## Task V3: reescribir `_SecretVotingPhase` → un votante a la vez

**Files:**
- Modify: `lib/screens/votacion_screen.dart`

Contexto del estado existente en `_VotacionScreenState`: `Map<String,String> _votos` (votanteId→votadoId), `_todosVotaron()`, `_votar(votanteId, votadoId)`, `_revelarResultado()`, `_cambiarAVotoUnanime()`, `_mostrarVotacionUnanime`. La fase secreta se construye con `_SecretVotingPhase(...)`. Los jugadores vivos: `widget.partida.jugadoresVivos`.

- [ ] **Step 1: Añadir estado de "handoff" en `_VotacionScreenState`**

Agregar campo y helpers (debajo de los campos existentes):
```dart
  // Voto secreto un-a-la-vez: índice del votante actual y si estamos en el
  // paso de "pasa el celular" entre votantes (para no revelar el voto previo).
  bool _mostrandoHandoff = false;

  /// Votante actual = primer jugador vivo que aún no ha votado (en orden).
  Jugador? get _votanteActual {
    for (final j in widget.partida.jugadoresVivos) {
      if (!_votos.containsKey(j.id)) return j;
    }
    return null;
  }

  void _registrarVotoSecreto(String votanteId, String votadoId) {
    AudioService.playClick();
    setState(() {
      _votos[votanteId] = votadoId;
      // Si aún faltan votantes, mostrar handoff antes del siguiente.
      _mostrandoHandoff = _votanteActual != null;
    });
  }

  void _continuarSiguienteVotante() {
    AudioService.playClick();
    setState(() => _mostrandoHandoff = false);
  }
```
(Importar `Jugador` si no está; el archivo ya lo usa.)

- [ ] **Step 2: Reemplazar la rama `else` (voto secreto) en `build`**

Donde hoy se construye `_SecretVotingPhase(...)`, pásale lo necesario para el nuevo flujo. Sustituir la construcción por:
```dart
                else
                  _SecretVotingPhase(
                    jugadoresVivos: jugadoresVivos,
                    votanteActual: _votanteActual,
                    mostrandoHandoff: _mostrandoHandoff,
                    votosCount: _votos.length,
                    totalVivos: totalVivos,
                    onVotar: _registrarVotoSecreto,
                    onContinuarHandoff: _continuarSiguienteVotante,
                    onCambiarAUnanime: _cambiarAVotoUnanime,
                    todosVotaron: _todosVotaron(),
                    onRevelar: _revelarResultado,
                  ),
```

- [ ] **Step 3: Reescribir el widget `_SecretVotingPhase`**

Reemplazar la clase `_SecretVotingPhase` (y eliminar `_VoteSelector`/`_VotedRow` si quedaran sin uso) por:
```dart
class _SecretVotingPhase extends StatelessWidget {
  const _SecretVotingPhase({
    required this.jugadoresVivos,
    required this.votanteActual,
    required this.mostrandoHandoff,
    required this.votosCount,
    required this.totalVivos,
    required this.onVotar,
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
  final void Function(String votanteId, String votadoId) onVotar;
  final VoidCallback onContinuarHandoff;
  final VoidCallback onCambiarAUnanime;
  final bool todosVotaron;
  final VoidCallback onRevelar;

  @override
  Widget build(BuildContext context) {
    // Todos votaron → botón de revelar.
    if (todosVotaron || votanteActual == null) {
      return Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.how_to_vote_rounded,
                color: AppColors.safe, size: 56),
            const SizedBox(height: 16),
            const AutoFitTitle('Todos votaron',
                style: AppType.titleL, maxLines: 1),
            const SizedBox(height: 8),
            Text('$votosCount/$totalVivos', style: AppType.bodyS),
            const SizedBox(height: 24),
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

    // Handoff: pasa el celular al siguiente votante (mantiene el voto secreto).
    if (mostrandoHandoff) {
      return Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.phone_android_rounded,
                color: AppColors.textSecondary, size: 56),
            const SizedBox(height: 16),
            Text('Voto registrado', style: AppType.bodyS),
            const SizedBox(height: 8),
            AutoFitTitle('Pasa el celular a\n${votanteActual!.nombre}',
                style: AppType.titleL, textAlign: TextAlign.center, maxLines: 2),
            const SizedBox(height: 24),
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

    // Turno del votante actual: rejilla de candidatos (todos menos él).
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
                const TextSpan(
                    text: 'Vota: ',
                    style: TextStyle(color: AppColors.textSecondary)),
                TextSpan(
                  text: votanteActual!.nombre,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text('¿Quién es el impostor?', style: AppType.bodyS),
          const SizedBox(height: 8),
          Expanded(
            child: AdaptiveAvatarGrid(
              items: candidatos,
              onTap: (item) => onVotar(votanteActual!.id, item.id),
            ),
          ),
          // Acceso a voto unánime — secundario contorno (on-tone).
          TextButton.icon(
            onPressed: onCambiarAUnanime,
            icon: const Icon(Icons.balance_rounded,
                color: AppColors.textSecondary, size: 18),
            label: Text('Votación unánime',
                style: AppType.bodyS.copyWith(
                    color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 4),
          _ProgresoVotos(votosCount: votosCount, totalVivos: totalVivos),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Puntos de progreso "x / n votaron".
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
          spacing: 4,
          children: [
            for (var i = 0; i < totalVivos; i++)
              Container(
                width: 16, height: 5,
                decoration: BoxDecoration(
                  color: i < votosCount ? AppColors.safe : AppColors.surfaceHigh,
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
```
Añadir el import al inicio del archivo: `import '../widgets/adaptive_avatar_grid.dart';`.

- [ ] **Step 4: Verificar**

Run: `flutter analyze lib/screens/votacion_screen.dart`
Expected: "No issues found!" (si quedan `_VoteSelector`/`_VotedRow` sin usar, eliminarlos).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/votacion_screen.dart lib/widgets/adaptive_avatar_grid.dart
git commit -m "feat(votación): voto secreto un-a-la-vez con rejilla simétrica + handoff"
```

## Task V4: `_UnanimousVotingPhase` con la misma rejilla (selección única)

**Files:**
- Modify: `lib/screens/votacion_screen.dart`

- [ ] **Step 1: Reescribir `_UnanimousVotingPhase`** para usar `AdaptiveAvatarGrid` con `selectedId` = el jugador elegido; debajo, "Volver a voto secreto" (secundario) y "Eliminar jugador" (`AppButton` danger) cuando hay selección. Mantener los callbacks existentes (`onSelect`, `onCambiarASecreto`, `onConfirmar`, `seleccionado`).
```dart
class _UnanimousVotingPhase extends StatelessWidget {
  const _UnanimousVotingPhase({
    required this.jugadoresVivos,
    required this.seleccionado,
    required this.onSelect,
    required this.onCambiarASecreto,
    required this.onConfirmar,
  });

  final List<Jugador> jugadoresVivos;
  final String? seleccionado;
  final ValueChanged<String> onSelect;
  final VoidCallback onCambiarASecreto;
  final VoidCallback onConfirmar;

  @override
  Widget build(BuildContext context) {
    final items = jugadoresVivos
        .map((j) => AvatarItem(id: j.id, label: j.nombre))
        .toList();
    return Expanded(
      child: Column(
        children: [
          const AutoFitTitle('Votación unánime',
              style: AppType.titleL, maxLines: 1),
          const SizedBox(height: 4),
          Text('Todos votan al mismo jugador', style: AppType.bodyS),
          const SizedBox(height: 8),
          Expanded(
            child: AdaptiveAvatarGrid(
              items: items,
              selectedId: seleccionado,
              onTap: (item) => onSelect(item.id),
            ),
          ),
          TextButton.icon(
            onPressed: onCambiarASecreto,
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppColors.textSecondary, size: 18),
            label: Text('Volver a voto secreto',
                style: AppType.bodyS.copyWith(
                    color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          if (seleccionado != null)
            AppButton(
              text: 'Eliminar jugador',
              icon: Icons.how_to_vote_rounded,
              variant: AppButtonVariant.danger,
              onPressed: onConfirmar,
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verificar** `flutter analyze lib/screens/votacion_screen.dart` → 0 errores.
- [ ] **Step 3: Commit**

```bash
git add lib/screens/votacion_screen.dart
git commit -m "style(votación): voto unánime con rejilla de caras (selección única)"
```

## Task V5: verificación final

- [ ] **Step 1:** `flutter analyze` (proyecto) → 0 errores.
- [ ] **Step 2:** `flutter test` → todos pasan (incluye `adaptive_avatar_grid_test`, `jugador_inicial_test`, los existentes).
- [ ] **Step 3:** Ejecutar en emulador y comprobar manualmente:
  - Con 4, 8 y 12 jugadores: la rejilla de voto entra **sin scroll**, simétrica y centrada; caras no gigantes.
  - Votar pasa al **handoff** ("pasa el celular a X") y luego al siguiente votante; al final, "Revelar resultado".
  - "Votación unánime" cambia de modo, seleccionas una cara y "Eliminar jugador" funciona; "Volver a voto secreto" regresa.
  - El conteo/empate/eliminación y la navegación a Resultado de ronda siguen correctos.
- [ ] **Step 4:** Commit si hubo ajustes: `chore(votación): verificación final`.

---

## Self-Review (cobertura)
- Opción A (un votante a la vez) → V3. ✓
- Rejilla simétrica adaptativa, sin scroll/espacio sobrante, tope de tamaño → V1 (helper, testeado) + V2 (widget centrado). ✓
- Voto unánime conservado → V4 (misma rejilla, lógica intacta). ✓
- Botón unánime on-tone (secundario/gris) → V3 y V4 (TextButton gris). ✓
- Lógica de conteo/empate/eliminación + PopScope + timer + "Empieza: X" → sin cambios. ✓
- Tipos consistentes: `AvatarItem`/`GridLayout`/`computeAvatarLayout`/`AdaptiveAvatarGrid` definidos en V1-V2 y usados en V3-V4. ✓
- Secreto del voto: paso de "handoff" entre votantes evita ver el voto anterior. ✓

## Notas
- Color del botón unánime por defecto: **secundario contorno/gris** (`textSecondary`). Para variante B (chip `surfaceHigh`) o C (solo texto), es un cambio de estilo trivial en los dos `TextButton`.
- `Random`/orden de votantes: el votante actual se deriva del orden de `jugadoresVivos` (estable).
