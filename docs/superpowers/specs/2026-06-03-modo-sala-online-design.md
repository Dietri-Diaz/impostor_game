# Spec — Modo Sala Online (Firebase, host-authoritative)

- **Fecha:** 2026-06-03
- **Proyecto:** `impostor_game` (Flutter)
- **Estado:** Diseño aprobado por el usuario (secciones 1-6). Pendiente: plan de implementación.

## 1. Contexto y objetivo

El modo local está cerrado al 100% (rediseño Minimal Bold, multi-impostor, persistencia, etc.).
Objetivo: añadir un **modo "Sala Online"** donde cada jugador usa **su propio celular**, se unen por un **código**, **cada uno ve su rol en su pantalla** (tripulante/impostor) y **cada uno vota desde su dispositivo** (no hay voto unánime en este modo).

El **modo local queda 100% intacto**; "Sala online" es una entrada nueva desde el Home.

## 2. Decisiones tomadas (con el usuario)

- **Backend:** Firebase Realtime Database (RTDB), plan gratuito **Spark** (sin tarjeta). Uso personal/amigos.
- **Auth:** Firebase **Anonymous Auth** (UID estable por instalación).
- **Modelo de autoridad:** **Host-authoritative**. El celular del anfitrión corre la lógica (reutiliza `PartidaManager`) y publica el estado. No se usan Cloud Functions (Spark no las incluye sin tarjeta).
- **Anti-trampa:** el rol/personaje vive **solo** en `/privado/{uid}`, protegido por reglas; `/publico` nunca contiene roles.
- **Cierre de votación:** se resuelve cuando **todos los vivos+conectados** votaron; el host puede **forzar cierre** si alguien quedó AFK.
- **Discusión → votación:** **el anfitrión abre la votación** manualmente (no hay temporizador automático en V1).
- **Reconexión:** simple (recuperas tu rol/estado al volver). **Host se va → la sala termina** con aviso. Sin migración de host en V1.
- **Sin** abstracción `PartidaSource`: se reutiliza la **lógica** (`PartidaManager`, `SesionJuego`) y el **design system**, no las pantallas. Los flujos local y online son pantallas distintas.

## 3. Arquitectura

```
Flutter (cliente)
 ├─ Modo Local  → pantallas actuales (intactas)
 └─ Modo Online → pantallas nuevas
       ├─ FirebaseService     (init + auth anónima)
       ├─ SalaOnlineManager   (crear/unirse/salir, código único, presencia)
       └─ RondaOnlineSync     (host: PartidaManager ⇄ Firebase ; cliente: Firebase → UI)
Firebase RTDB  ← única vía de sincronización
```

- **Anfitrión** = motor autoritativo (corre `PartidaManager`) **+** un jugador más (ve su rol y vota como todos).
- **Clientes (no-host)** = renderizan lo que Firebase empuja y solo escriben *su* voto / *su* "listo" / *su* nombre.
- La lógica de juego (asignar roles, "quién empieza", contar votos, fin de juego, marcador) **no se reescribe**: corre en `PartidaManager`/`SesionJuego` del host.

### Adaptación necesaria a `PartidaManager`

`crearPartida` genera ids con `uuid.v4()`. En online los ids de jugador deben ser los **UID de Firebase**. Se añade una vía para construir la `Partida` a partir de un roster existente (uid + nombre + número) sin tocar la lógica de asignación de roles. No se modifica el comportamiento del modo local.

## 4. Modelo de datos (RTDB)

```
/salas/{CODIGO}/
  meta/       hostUid, estado, rondaActual, tematica, configJson,
              jugadorInicialUid, hostConectado, createdAt
  jugadores/{uid}/   nombre, numero, conectado, listo, eliminado
  publico/    fase, jugadoresVivos[], conteoVotos{uid:n},
              resultadoRonda{eliminadoUid, eraImpostor}, ganador, puntuacion{uid:pts}
  privado/{uid}/     esImpostor(bool), personajeVisto(string | null)   ← el secreto vive SOLO aquí
  votos/{uid}/       objetivoUid
/codigos/{CODIGO}     salaId/createdAt  (índice de unicidad)
```

Estados (`meta.estado`): `lobby → revelando → discusion → votando → resultado → (siguiente ronda | finalizada)`, más `abandonada`.

### Reglas de seguridad (`database.rules.json`) — el corazón del anti-trampa

- `privado/{uid}`: **read** solo ese `uid`; **write** solo el host. → Nadie puede leer el rol/personaje ajeno, ni consultando la base directo.
- `publico`: **write** solo el host; **read** miembros de la sala. Nunca contiene roles.
- `votos/{uid}`: **write** solo ese `uid` y solo mientras `estado == votando`; **read** solo el host (voto secreto hasta el conteo público).
- `jugadores/{uid}`: **write** propio (nombre/listo/conectado); el host puede escribir `eliminado`.
- `meta`: **write** solo el host (o al crear, si no existe).
- `codigos/{codigo}`: **write** solo si no existe (unicidad bajo concurrencia).

## 5. Flujo end-to-end por estado

Cada transición la dispara el **anfitrión** (único que escribe `meta`/`publico`); los demás reaccionan vía stream.

| Estado | Jugador | Anfitrión |
|---|---|---|
| `lobby` | Código grande, lista en vivo, nombre editable, botón "Listo". | Config (temática, nº impostores, eliminar-en-empate). "Empezar partida" (≥3). |
| `revelando` | Su carta: **solo su rol** (impostor sin personaje; civil con personaje). "Entendido". | Asignó roles, escribió `/privado/{uid}` de cada quien. Espera confirmaciones. |
| `discusion` | "🗣️ Empieza: X" + temática. Discusión hablada. | "Abrir votación". |
| `votando` | Rejilla de caras de **vivos** (`AdaptiveAvatarGrid`) → toca → hoja de confirmación → escribe voto. "Ya votaste". | Progreso "5/7". "Cerrar votación" (forzar). |
| `resultado` | Eliminado + si era impostor + marcador. | Contó votos, eliminó, verificó fin. "Siguiente ronda" / "Resultado final". |
| `finalizada` | Ganador + ranking de sesión. | "Nueva partida" (mismo grupo) / "Cerrar sala". |
| `abandonada` | "El anfitrión salió" → Home. | — |

Reglas reutilizadas tal cual del modo local: asignación aleatoria, clamp `impostores < civiles`, "quién empieza" sesgado (impostor tarde, a veces primero ~1/10), conteo de votos, empate según config, fin de juego, marcador de `SesionJuego`.

## 6. Pantallas nuevas (reusan el design system)

Home: bloque "Jugar online" con 2 botones (Crear / Unirse).

1. `crear_sala_screen.dart` — nombre + temática + config → crea sala, muestra código.
2. `unirse_sala_screen.dart` — código de 6 caracteres + nombre → entra.
3. `lobby_online_screen.dart` — `StreamBuilder` sobre la sala; lista en vivo, "Listo", controles de host.
4. `revelar_rol_online_screen.dart` — lee **solo** `/privado/{miUid}`; reusa carta/anti-spoiler.
5. `votacion_online_screen.dart` — rejilla + hoja de confirmación (UX ya pulida), voto secreto.
6. `resultado_ronda_online_screen.dart` — reusa el look de resultado actual.
7. Resultado final: **reuso** de `resultado_final_screen.dart` con datos de sesión online.

Todas con `AppScaffold`/`AppButton`/`AppType`/`AppCard`/`AdaptiveAvatarGrid` existentes.

## 7. Lógica nueva (no UI)

- `lib/services/firebase_service.dart` — singleton: `Firebase.initializeApp()` + `signInAnonymously()` automático; expone `uid`.
- `lib/managers/sala_online_manager.dart` — crear/unirse/salir; generación de código único de 6 chars (sin O/0, I/1/L) con `runTransaction` sobre `/codigos/{codigo}` (reintento hasta 5 veces); presencia (`onDisconnect`).
- `lib/managers/ronda_online_sync.dart` — host: refleja `PartidaManager`→`/publico` + `/privado/{uid}`, ingiere votos/listos/joins; cliente: `/publico` + `/privado/{miUid}` → estado de UI.

## 8. Reconexión, presencia, host se va

- UID anónimo estable; código de sala activa guardado en `SharedPreferences`.
- Reconexión simple: al volver, si hay sala activa → relees `/privado/{uid}` + `/publico` → vuelves a la fase actual con rol intacto.
- Presencia: cada jugador `conectado=true` con `onDisconnect()→false`; lobby en vivo. El conteo "todos votaron" considera solo **vivos+conectados** (un desconectado no traba; refuerzo: "cerrar votación" del host).
- Host se va: `onDisconnect()` del host marca `meta.estado='abandonada'` → todos ven aviso y vuelven al Home. Sin migración de host (V1).

## 9. Alcance

**Dentro de V1:** crear/unirse por código, lobby en vivo, revelación por dispositivo, discusión con "quién empieza", votación secreta individual (con cierre forzado del host), resultado, multironda con marcador, reconexión simple, host-se-va. Min 3 / **máx 12**. Código 6 chars sin ambiguos.

**Fuera de V1:** migración de host, chat in-game, perfiles persistentes, espectadores, estadísticas entre sesiones, iOS (V1 se prueba en Android).

## 10. Setup Firebase (paso manual del usuario, con guía)

1. console.firebase.google.com → **Add project** `impostor-game` → sin Analytics → Create.
2. Build → **Realtime Database** → Create → ubicación cercana → Start in locked mode.
3. Build → **Authentication** → Get started → Sign-in method → habilitar **Anonymous** → Save.
4. ⚙️ Project settings → Your apps → **Android** → package `com.dreamers.impostorgame` (verificar el real) → descargar **`google-services.json`** → colocar en `android/app/`.
5. RTDB → Rules → pegar `database.rules.json` del repo.

Gradle: plugin `com.google.gms.google-services` en `android/` y aplicarlo en `android/app`. `main.dart`: `await Firebase.initializeApp()` antes de `runApp`.

## 11. Pruebas

- **Lógica pura** (asignación, "quién empieza", conteo, fin): los tests existentes siguen cubriéndola (no cambia).
- **Multijugador local:** correr la app en **emulador + cel físico** (o emulador + Chrome web) para simular 2+ jugadores.
- Smoke test: crear sala → unirse 2-3 dispositivos → revelar (cada uno su rol) → discusión → votar todos → resultado → siguiente ronda → fin. Probar: AFK + cierre forzado; host cierra app → "abandonada"; reconexión.

## 12. Riesgos y mitigaciones

1. **Race en votación** (dos votos casi simultáneos / doble proceso del host) → host solo cuenta cuando `estado==votando` y marca `votacionCerrada`; ignora votos fuera de fase.
2. **Host desconectado a mitad** → `onDisconnect().update({estado:'abandonada'})` + pantalla "el host salió". Sin handover en V1.
3. **Código duplicado bajo concurrencia** → `runTransaction` sobre `/codigos/{codigo}` con reintento.
4. **Spark sin Cloud Functions** → toda la autoridad vive en el cliente host (aceptado para uso entre amigos).

## 13. Reutilización (resumen)

- **Lógica:** `PartidaManager` (motor), `SesionJuego` (marcador), `tematicas_data`, validadores, enums.
- **UI:** `AppScaffold`, `AppButton`, `AppType`, `AppColors`, `AppCard`/`AppChip`/`AppSheet`, `AdaptiveAvatarGrid`, `AutoFitTitle`, `resultado_final_screen`.
- **Nuevo:** 3 módulos de lógica online + 6 pantallas online + reglas RTDB + setup Firebase.
