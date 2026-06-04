# Rediseño IMPOSTOR — "Minimal Bold"

- **Fecha:** 2026-06-02
- **Proyecto:** impostor_game (Flutter / Dart)
- **Objetivo del usuario:** mejorar drásticamente el diseño del juego, corregir el bug de "al regresar se borra la partida" y eliminar errores visuales / glitches.

## 1. Objetivos y alcance

### Objetivos
1. Rediseñar **todas** las pantallas con una identidad visual coherente y de alta calidad ("Minimal Bold").
2. Corregir el bug donde, al iniciar una partida y regresar accidentalmente, se pierde/borra la sesión guardada.
3. Eliminar errores visuales y glitches (tema roto, desbordes de texto, falta de pulido).

### Fuera de alcance
- Lógica/reglas del juego (`PartidaManager`, modelos, validadores) — **no se modifican** salvo lo necesario para los bugs de navegación.
- Base de datos (SQLite) y repositorios.
- El feature pendiente de "multijugador online".

## 2. Decisiones cerradas (validadas con el usuario)

| Decisión | Elección |
|---|---|
| Dirección visual | **Minimal Bold** (fondo casi negro, tipografía grande, color disciplinado, aire) |
| Tipografía títulos | **Anton** (condensada tipo póster), **incrustada** (offline) |
| Tipografía cuerpo | **Inter**, incrustada |
| Modo de tema | **Solo oscuro** (se elimina el modo claro y el toggle) |
| Pantalla de revelación | Layout "ícono protagonista", **fondo oscuro discreto por defecto** (anti-spoiler) |
| Modo a todo color | **Opción** en Ajustes ("Pantalla a todo color": rojo impostor / menta civil a sangre completa) |
| Enfoque de ejecución | **Sistema de diseño primero**, luego re-skin pantalla por pantalla |

## 3. Sistema de diseño (`lib/core/app_theme.dart` reconstruido)

### 3.1 Paleta
- **Fondo (tinta):** `#0B0B0D`
- **Superficie / tarjeta:** `#16161A` (borde sutil `rgba(255,255,255,0.08)`)
- **Texto:** blanco `#FFFFFF` (primario), `#9A9AA2` (secundario), `#6B6B73` (muted)
- **Acento peligro / impostor:** `#E0223E`
- **Acento seguro / civil / victoria:** `#22C55E`
- **Oro (solo #1 del marcador):** `#FFD700`

Se elimina la paleta dispersa actual (8 `cardGradients`, múltiples gradientes). Disciplina: tinta + blanco + rojo + verde menta, y oro solo para el líder.

### 3.2 Tipografía
- **Anton** para `display`/títulos; **Inter** (400/500/600/700/800) para cuerpo/etiquetas.
- Ambas se **incrustan como assets** y se declaran en `pubspec.yaml` `fonts:` (la app es offline; no usar carga remota de Google Fonts).
- Escala fija: `displayXL`, `displayL`, `titleL`, `titleM`, `body`, `bodyS`, `label`.

### 3.3 Espaciado y radios
- Escala de espaciado: 4 / 8 / 12 / 16 / 20 / 24 / 32.
- Radios: tarjetas 16–20, chips/botones tipo "pill".

### 3.4 Componentes reutilizables (nuevos / refactorizados)
- `AppScaffold` — fondo tinta + SafeArea + header opcional.
- `AppButton` — variantes `primary` (relleno blanco), `secondary` (contorno), `danger` (rojo); con micro-escala al presionar + `HapticFeedback`.
- `AppCard` — superficie sobria (sin gradientes ruidosos), borde sutil.
- `AppChip` / `RoleBadge` — chips para jugadores y badges de rol.
- **`AutoFitTitle`** — envuelve el título en `FittedBox`/auto-escalado para que **nunca** se desborde (clave para celulares angostos).
- `AppHeader` — refactor del actual.
- Transiciones de página unificadas (una `SlideFade` estándar; se conserva `FadeScale` solo para momentos especiales).

## 4. Correcciones de bugs

### 4.1 Bug principal — "al regresar se borra la partida"
- **Causa:** en `lib/screens/home_screen.dart`, el botón "JUGAR AHORA" llama a `clearActiveSession()` **inmediatamente**, antes de navegar a la configuración. Si el usuario tiene una sesión guardada y toca "JUGAR AHORA" por error y luego regresa, la sesión ya fue borrada.
- **Arreglo:** **no** borrar la sesión al entrar a la configuración. Una nueva sesión solo debe sobrescribir la guardada cuando **llega de verdad al Lobby** (`LobbyScreen` ya hace `saveNow()` y sobrescribe el JSON). Así, si el usuario retrocede a media configuración, la sesión anterior queda intacta y "Continuar" sigue disponible.
- **Resultado esperado:** retroceder durante la configuración nunca destruye una partida guardada.

### 4.2 Botón "atrás" del sistema sin protección
- **Causa:** no hay `PopScope`/`WillPopScope`. En el Lobby, el botón atrás físico de Android omite el diálogo de confirmación; en Votación, retroceder a media ronda pierde la discusión sin aviso.
- **Arreglo:**
  - **Lobby:** `PopScope` que dispara el mismo diálogo "¿Salir de la sesión?". Importante: salir del lobby **no** borra la sesión (solo el botón explícito "Salir" lo hace), así que aunque se salga, "Continuar" permanece.
  - **Votación:** `PopScope` con confirmación "¿Salir de la ronda? Volverás al lobby" antes de perder votos/discusión.

### 4.3 Bug de tema claro/oscuro
- **Causa:** en `lib/main.dart`, `theme:` y `darkTheme:` apuntan **ambos** a `AppTheme.darkTheme`; `lightTheme` nunca se aplica. En modo claro, los componentes nativos (diálogos, snackbars, inputs, `ExpansionTile`) seguían en oscuro → inconsistencia visual.
- **Arreglo:** al pasar a **solo oscuro**, se elimina `lightTheme`, `ThemeNotifier`, el toggle de tema y la clave `theme.is_dark`. `MaterialApp` usa un único `darkTheme`. Esto borra de raíz la clase de bug.

### 4.4 Desborde de texto en pantallas angostas
- **Causa:** títulos grandes con tamaño fijo (ej. "IMPOSTOR", "GANAN LOS CIVILES") pueden cortarse/desbordarse en celulares chicos.
- **Arreglo:** todos los títulos grandes usan `AutoFitTitle` (auto-escalado). Sin hifenación manual.

### 4.5 Pulido y estabilidad ("que no se bugee")
- `HapticFeedback` en taps clave, revelación de rol y victoria.
- Revisar `dispose()` de todos los `AnimationController`/`Timer` (ya en su mayoría correcto).
- Reescribir la estructura/indentación irregular de `_buildRolReveal` en `revelar_roles_screen.dart`.
- Unificar transiciones para evitar saltos visuales entre pantallas.

## 5. Pantalla por pantalla

> Todas heredan el sistema de diseño (fondo tinta, Anton/Inter, componentes nuevos).

1. **HomeScreen** — wordmark Anton grande; botón blanco "Jugar"; "Continuar (N rondas)" como acción secundaria; features como lista sobria; se quita la capa de partículas ruidosa y el toggle de tema. (Aquí va el fix 4.1.)
2. **ConfigurarPartidaScreen (temáticas)** — grid de temáticas con logos; selección por borde/realce, sin gradientes saturados.
3. **ConfigurarJugadoresScreen** — filas limpias; autocompletado/historial conservado; configuración en hoja inferior.
4. **LobbyScreen** — marcador, jugadores como chips, selector de impostores, historial; tarjetas sobrias. (Fix 4.2 Lobby.)
5. **PasarTelefonoScreen** — sobria; nombre grande auto-escalado; botón "Estoy listo".
6. **RevelarRolesScreen** — layout "ícono protagonista"; **fondo oscuro discreto por defecto**; lee el ajuste "Pantalla a todo color" para el modo a sangre completa. Impostor = anillo/chip rojo + ☠️; Civil = anillo/chip menta + avatar del personaje. (Fix 4.4, 4.5.)
7. **VotacionScreen** — rediseño del `ExpansionTile` a tarjetas claras; temporizador grande; voto secreto/unánime. (Fix 4.2 Votación.)
8. **ResultadoRondaScreen** — bloques de color audaces (verde/rojo/empate), tipografía gigante auto-escalada, conteo de votos, jugadores restantes; auto-retorno al lobby conservado.
9. **ResultadoFinalScreen** — bloque de victoria/derrota; revelación de personaje e impostores; estadísticas y marcador; confeti **discreto** solo en victoria.
10. **ReglasScreen** — mismo lenguaje visual; PageView conservado.
11. **ListaTematicasScreen / CrearTematicaScreen** — mismas tarjetas y formularios sobrios.

## 6. Ajustes (Home → hoja de Ajustes)
- Conserva "Saltar Pasa el teléfono".
- **Nuevo:** "Pantalla a todo color" (bool, default `false`). Nueva clave en `PreferencesService` (ej. `gameplay.colorful_reveal`).
- Se elimina el toggle de tema (solo oscuro).

## 7. Notas técnicas
- `pubspec.yaml`: agregar assets de fuentes (`assets/fonts/Anton-Regular.ttf`, `Inter-*.ttf`) y bloque `fonts:`.
- Eliminar `lib/core/theme_notifier.dart` y referencias; simplificar `main.dart`.
- `AppTheme` deja de ser un toggle dinámico estático y pasa a ser tokens estáticos de modo oscuro.
- Sin cambios en `database/`, `repositories/`, `managers/`, `models/` (salvo que un bug lo exija).
- Mantener todos los textos en español.

## 8. Criterios de éxito
- Retroceder durante la configuración **no** borra una partida guardada; "Continuar" sigue apareciendo.
- Atrás físico en Lobby/Votación pide confirmación y no pierde la sesión.
- No hay inconsistencias de tema (solo oscuro, coherente en todas las pantallas y componentes nativos).
- Ningún título se desborda en celulares chicos (probar equivalente a iPhone SE).
- Todas las pantallas comparten la identidad Minimal Bold (Anton/Inter, paleta disciplinada).
- Revelación discreta por defecto; modo a todo color disponible en Ajustes.
- `flutter analyze` sin errores nuevos; tests existentes siguen pasando.
