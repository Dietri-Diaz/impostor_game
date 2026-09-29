# Modo Sala Online — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Añadir un modo "Sala Online" donde cada jugador usa su propio celular, se une por código, ve solo su rol, y vota desde su dispositivo — reutilizando la lógica de juego local (`PartidaManager`/`SesionJuego`) con Firebase RTDB como canal de sincronización host-authoritative.

**Architecture:** El celular del anfitrión corre `PartidaManager` como motor autoritativo y publica el estado a Firebase RTDB; los demás clientes solo leen su estado y escriben su voto/listo. Toda la I/O de Firebase pasa por un seam `SalaGateway` (interfaz) con una implementación real (`FirebaseSalaGateway`) y una fake en memoria (`FakeSalaGateway`) para tests. El modo local queda intacto.

**Tech Stack:** Flutter/Dart, `firebase_core`, `firebase_auth` (anónima), `firebase_database` (RTDB), Provider, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-06-03-modo-sala-online-design.md`

---

## File Structure

**Nuevos (lógica):**
- `lib/services/firebase_service.dart` — init Firebase + auth anónima; expone `uid`.
- `lib/services/sala_gateway.dart` — interfaz `SalaGateway` (I/O RTDB) + DTOs de sala.
- `lib/services/firebase_sala_gateway.dart` — implementación real con `firebase_database`.
- `lib/managers/sala_codigo.dart` — generador puro de código de sala.
- `lib/managers/sala_online_manager.dart` — crear/unirse/salir/presencia (usa `SalaGateway`).
- `lib/managers/ronda_online_sync.dart` — host: `PartidaManager`→RTDB; cliente: RTDB→UI.

**Nuevos (UI):**
- `lib/screens/online/crear_sala_screen.dart`
- `lib/screens/online/unirse_sala_screen.dart`
- `lib/screens/online/lobby_online_screen.dart`
- `lib/screens/online/revelar_rol_online_screen.dart`
- `lib/screens/online/votacion_online_screen.dart`
- `lib/screens/online/resultado_ronda_online_screen.dart`

**Nuevos (tests):**
- `test/online/partida_fromjson_test.dart`
- `test/online/crear_partida_ids_test.dart`
- `test/online/sala_codigo_test.dart`
- `test/online/sala_dtos_test.dart`
- `test/online/sala_online_manager_test.dart`
- `test/online/ronda_online_sync_test.dart`
- `test/online/fake_sala_gateway.dart` (helper, no es un test)

**Nuevos (infra):**
- `database.rules.json` (raíz del repo)
- `android/app/google-services.json` (lo coloca el usuario, NO se commitea — va a `.gitignore`)

**Modificados:**
- `lib/models/partida.dart` — añadir `Partida.fromJson`.
- `lib/models/ronda.dart` — añadir `Ronda.fromJson`.
- `lib/managers/partida_manager.dart` — `crearPartida` acepta `List<String>? ids`.
- `lib/main.dart` — `Firebase.initializeApp()` + proveer `FirebaseService`.
- `lib/screens/home_screen.dart` — bloque "Jugar online" (2 botones).
- `pubspec.yaml` — deps de Firebase.
- `android/app/build.gradle.kts`, `android/build.gradle.kts`, `android/settings.gradle.kts` — plugin google-services.
- `.gitignore` — ignorar `google-services.json`.

---

## Phase 0 — Firebase setup & conectividad

Produce: la app arranca con Firebase inicializado y auth anónima funcionando (UID en pantalla de debug).

### Task 0.1: Setup manual del usuario en Firebase Console

Esto lo hace el usuario (no es código). El agente PAUSA aquí hasta que confirme.

- [ ] **Step 1: Guía al usuario**

Indicar exactamente:
1. https://console.firebase.google.com → **Add project** → nombre `impostor-game` → desactivar Google Analytics → Create.
2. Build → **Realtime Database** → Create Database → ubicación más cercana (ej. `us-central1`) → **Start in locked mode**.
3. Build → **Authentication** → Get started → pestaña "Sign-in method" → habilitar **Anonymous** → Save.
4. ⚙️ Project settings → "Your apps" → ícono **Android** → Android package name **exactamente** `com.dreamers.impostorgame` → Register app → **descargar `google-services.json`**.
5. Colocar `google-services.json` en `c:\Users\dietr\Desktop\Pruebas\impostor_game\android\app\`.
6. En Realtime Database → pestaña "Rules": dejar como está por ahora (se reemplaza en Phase 8). Copiar la **URL de la base** (ej. `https://impostor-game-xxxx-default-rtdb.firebaseio.com`) — se usará en `FirebaseService`.

- [ ] **Step 2: Verificar que el archivo existe**

Run: `ls android/app/google-services.json`
Expected: el archivo existe.

### Task 0.2: Ignorar google-services.json en git

**Files:** Modify: `.gitignore`

- [ ] **Step 1: Añadir la línea**

Añadir al final de `.gitignore`:
```
# Firebase (config local, no subir secretos del proyecto)
android/app/google-services.json
lib/firebase_options.dart
```

- [ ] **Step 2: Verificar que git lo ignora**

Run: `git -C . status --porcelain android/app/google-services.json`
Expected: salida vacía (git lo ignora).

### Task 0.3: Añadir dependencias de Firebase

**Files:** Modify: `pubspec.yaml`

- [ ] **Step 1: Añadir deps**

En `pubspec.yaml`, bajo `dependencies:` (después de `uuid: ^4.2.1`):
```yaml
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.1
  firebase_database: ^11.1.4
```

- [ ] **Step 2: Instalar**

Run: `flutter pub get`
Expected: "Got dependencies!" sin errores de resolución. Si hay conflicto de versión, ejecutar `flutter pub upgrade firebase_core firebase_auth firebase_database` y fijar las versiones resueltas.

### Task 0.4: Configurar Gradle para google-services

**Files:** Modify: `android/settings.gradle.kts`, `android/app/build.gradle.kts`

- [ ] **Step 1: Declarar el plugin en settings.gradle.kts**

En `android/settings.gradle.kts`, dentro del bloque `plugins { ... }`, añadir (sin `apply`):
```kotlin
    id("com.google.gms.google-services") version "4.4.2" apply false
```

- [ ] **Step 2: Aplicar el plugin en app/build.gradle.kts**

En `android/app/build.gradle.kts`, en el bloque `plugins { ... }`, añadir tras `id("kotlin-android")`:
```kotlin
    id("com.google.gms.google-services")
```

- [ ] **Step 3: Verificar compilación de configuración**

Run: `flutter build apk --debug --target-platform android-arm64` (o `flutter run` en el emulador hasta que compile)
Expected: compila sin error de "google-services plugin". Si falla por config-cache, ya está desactivado en `android/gradle.properties`.

### Task 0.5: FirebaseService (init + auth anónima)

**Files:** Create: `lib/services/firebase_service.dart`; Modify: `lib/main.dart`

- [ ] **Step 1: Crear FirebaseService**

```dart
// lib/services/firebase_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

/// Inicializa Firebase y mantiene una sesión anónima. El UID anónimo es
/// estable por instalación, lo que permite reconexión.
class FirebaseService {
  FirebaseService._(this.db);

  final FirebaseDatabase db;
  String? _uid;
  String get uid {
    final u = _uid;
    if (u == null) throw StateError('FirebaseService no inicializado');
    return u;
  }

  bool get estaListo => _uid != null;

  /// Llamar una sola vez en main() antes de runApp.
  static Future<FirebaseService> init() async {
    await Firebase.initializeApp();
    final db = FirebaseDatabase.instance;
    final service = FirebaseService._(db);
    final cred = await FirebaseAuth.instance.signInAnonymously();
    service._uid = cred.user!.uid;
    return service;
  }
}
```

- [ ] **Step 2: Cablear en main.dart**

Reemplazar `main()` y el árbol de providers en `lib/main.dart`:
```dart
import 'services/firebase_service.dart';
// ...
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  final sharedPrefs = await SharedPreferences.getInstance();
  final prefs = PreferencesService(sharedPrefs);
  final firebase = await FirebaseService.init();

  runApp(
    MultiProvider(
      providers: [
        Provider<PreferencesService>.value(value: prefs),
        Provider<FirebaseService>.value(value: firebase),
      ],
      child: const ImpostorGame(),
    ),
  );
}
```
Añadir el import de `provider` ya existe; usar `MultiProvider` (de `package:provider/provider.dart`).

- [ ] **Step 3: Smoke test manual**

Run: `flutter run -d emulator-5554`
Expected: la app arranca sin crash. Temporalmente, añadir en `HomeScreen.build` un `debugPrint(context.read<FirebaseService>().uid)` y verificar en consola que imprime un UID. Quitar el debugPrint después.

- [ ] **Step 4: Commit** — NO commitear aún (ver "Commit final": todo el feature va en un solo commit). Solo verificar `flutter analyze` = 0 issues.

---

## Phase 1 — Serialización (fromJson)

Produce: `Partida` y `Ronda` se pueden reconstruir desde JSON. Pure, testeable.

### Task 1.1: Partida.fromJson

**Files:** Modify: `lib/models/partida.dart`; Test: `test/online/partida_fromjson_test.dart`

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/online/partida_fromjson_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:impostor_game/models/partida.dart';
import 'package:impostor_game/models/configuracion_partida.dart';
import 'package:impostor_game/models/jugador.dart';

void main() {
  test('Partida round-trips through toJson/fromJson', () {
    final original = Partida(
      id: 'p1',
      tematica: 'Animales',
      personajeSecreto: 'León',
      configuracion: ConfiguracionPartida(numeroImpostores: 2),
      jugadores: [
        Jugador(id: 'u1', nombre: 'Ana', numero: 1, esImpostor: true),
        Jugador(id: 'u2', nombre: 'Beto', numero: 2, esImpostor: false),
      ],
    );

    final restored = Partida.fromJson(original.toJson());

    expect(restored.id, 'p1');
    expect(restored.tematica, 'Animales');
    expect(restored.personajeSecreto, 'León');
    expect(restored.jugadores.length, 2);
    expect(restored.jugadores.first.esImpostor, true);
    expect(restored.configuracion.numeroImpostores, 2);
    expect(restored.rondaActual, 1);
    expect(restored.finalizada, false);
  });
}
```

- [ ] **Step 2: Ejecutar y ver que falla**

Run: `flutter test test/online/partida_fromjson_test.dart`
Expected: FAIL — "The method 'fromJson' isn't defined for the type 'Partida'".

- [ ] **Step 3: Implementar Partida.fromJson**

Añadir en `lib/models/partida.dart` dentro de la clase, después de `toJson()`. Importar `ronda.dart` ya está. Importar `jugador.dart` ya está.
```dart
  factory Partida.fromJson(Map<String, dynamic> json) {
    final ganadorRaw = json['ganador'] as String?;
    return Partida(
      id: json['id'] as String,
      tematica: json['tematica'] as String,
      personajeSecreto: json['personajeSecreto'] as String,
      jugadores: [
        for (final j in (json['jugadores'] as List? ?? const []))
          Jugador.fromJson((j as Map).cast<String, dynamic>()),
      ],
      configuracion: ConfiguracionPartida.fromJson(
        (json['configuracion'] as Map).cast<String, dynamic>(),
      ),
      rondas: [
        for (final r in (json['rondas'] as List? ?? const []))
          Ronda.fromJson((r as Map).cast<String, dynamic>()),
      ],
      rondaActual: (json['rondaActual'] as int?) ?? 1,
      finalizada: (json['finalizada'] as bool?) ?? false,
      ganador: ganadorRaw == null
          ? null
          : TipoGanador.values.firstWhere((g) => g.name == ganadorRaw),
    );
  }
```
Añadir el import `import 'configuracion_partida.dart';` ya existe. `Ronda.fromJson` se crea en la Task 1.2 — escribir esta task primero hará que el test de Partida falle por `Ronda.fromJson` faltante; por eso ejecutar las dos tasks juntas: implementar 1.2 antes de correr 1.1. (Ver orden abajo.)

- [ ] **Step 4: (tras 1.2) Ejecutar y ver que pasa**

Run: `flutter test test/online/partida_fromjson_test.dart`
Expected: PASS.

### Task 1.2: Ronda.fromJson

**Files:** Modify: `lib/models/ronda.dart`

- [ ] **Step 1: Implementar Ronda.fromJson**

Añadir en `lib/models/ronda.dart` dentro de la clase, después de `toJson()`:
```dart
  factory Ronda.fromJson(Map<String, dynamic> json) {
    Map<String, String> parseVotos(Object? raw) {
      final m = (raw as Map?) ?? const {};
      return {for (final e in m.entries) e.key as String: e.value as String};
    }

    Map<String, int>? parseConteo(Object? raw) {
      if (raw == null) return null;
      final m = (raw as Map);
      return {for (final e in m.entries) e.key as String: e.value as int};
    }

    final elimRaw = json['jugadorEliminado'];
    final iniRaw = json['jugadorInicial'];
    return Ronda(
      numero: json['numero'] as int,
      jugadoresVivos: [
        for (final j in (json['jugadoresVivos'] as List? ?? const []))
          Jugador.fromJson((j as Map).cast<String, dynamic>()),
      ],
      votos: parseVotos(json['votos']),
      conteoVotos: parseConteo(json['conteoVotos']),
      jugadorEliminado: elimRaw == null
          ? null
          : Jugador.fromJson((elimRaw as Map).cast<String, dynamic>()),
      huboEmpate: (json['huboEmpate'] as bool?) ?? false,
      jugadoresEmpatados:
          (json['jugadoresEmpatados'] as List?)?.cast<String>(),
      jugadorInicial: iniRaw == null
          ? null
          : Jugador.fromJson((iniRaw as Map).cast<String, dynamic>()),
      inicio: DateTime.parse(json['inicio'] as String),
      fin: (json['fin'] as String?) == null
          ? null
          : DateTime.parse(json['fin'] as String),
    );
  }
```

- [ ] **Step 2: Ejecutar el test de Partida (cubre Ronda indirectamente) + analyze**

Run: `flutter test test/online/partida_fromjson_test.dart && flutter analyze`
Expected: PASS, 0 issues.

---

## Phase 2 — Roster adaptation (ids de Firebase)

Produce: `crearPartida` puede usar UIDs de Firebase como ids de jugador, sin cambiar el modo local.

### Task 2.1: crearPartida acepta ids opcionales

**Files:** Modify: `lib/managers/partida_manager.dart`; Test: `test/online/crear_partida_ids_test.dart`

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/online/crear_partida_ids_test.dart
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:impostor_game/managers/partida_manager.dart';
import 'package:impostor_game/models/configuracion_partida.dart';

void main() {
  test('crearPartida usa los ids provistos como id de jugador', () {
    final manager = PartidaManager(random: Random(1));
    final partida = manager.crearPartida(
      tematica: 'Animales',
      personajeSecreto: 'León',
      nombresJugadores: ['Ana', 'Beto', 'Caro'],
      ids: ['uidA', 'uidB', 'uidC'],
      configuracion: ConfiguracionPartida(),
    );
    expect(partida.jugadores.map((j) => j.id).toList(),
        ['uidA', 'uidB', 'uidC']);
    // Sigue asignando exactamente 1 impostor por defecto.
    expect(partida.jugadores.where((j) => j.esImpostor).length, 1);
  });

  test('crearPartida sin ids sigue generando uuids (modo local intacto)', () {
    final manager = PartidaManager(random: Random(1));
    final partida = manager.crearPartida(
      tematica: 'Animales',
      personajeSecreto: 'León',
      nombresJugadores: ['Ana', 'Beto', 'Caro'],
      configuracion: ConfiguracionPartida(),
    );
    expect(partida.jugadores.every((j) => j.id.isNotEmpty), true);
    expect(partida.jugadores.map((j) => j.id).toSet().length, 3);
  });
}
```

- [ ] **Step 2: Ejecutar y ver que falla**

Run: `flutter test test/online/crear_partida_ids_test.dart`
Expected: FAIL — "No named parameter with the name 'ids'".

- [ ] **Step 3: Implementar**

En `lib/managers/partida_manager.dart`, en `crearPartida`, añadir el parámetro y usarlo. Cambiar la firma:
```dart
  Partida crearPartida({
    required String tematica,
    required String personajeSecreto,
    required List<String> nombresJugadores,
    required ConfiguracionPartida configuracion,
    List<String>? ids,
  }) {
```
Y donde se construye la lista de `Jugador` (la llamada `List.generate`), reemplazar el `id`:
```dart
    if (ids != null && ids.length != n) {
      throw PartidaException('ids debe tener la misma longitud que nombres');
    }
    final jugadores = List.generate(
      n,
      (index) => Jugador(
        id: ids != null ? ids[index] : _uuid.v4(),
        nombre: nombresJugadores[index].trim(),
        numero: index + 1,
        esImpostor: impostorIndices.contains(index),
      ),
    );
```

- [ ] **Step 4: Ejecutar y ver que pasa + no romper tests existentes**

Run: `flutter test test/online/crear_partida_ids_test.dart && flutter test`
Expected: PASS todos (incluye los 58 existentes).

---

## Phase 3 — Código de sala + DTOs + predicados (puros)

Produce: generador de código, DTOs serializables y predicados de fase. Todo puro y testeado.

### Task 3.1: Generador de código de sala

**Files:** Create: `lib/managers/sala_codigo.dart`; Test: `test/online/sala_codigo_test.dart`

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/online/sala_codigo_test.dart
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:impostor_game/managers/sala_codigo.dart';

void main() {
  test('código tiene 6 chars del alfabeto sin ambiguos', () {
    final r = Random(42);
    for (var i = 0; i < 200; i++) {
      final code = generarCodigoSala(r);
      expect(code.length, 6);
      expect(RegExp(r'^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$').hasMatch(code),
          true, reason: 'código inválido: $code');
    }
  });

  test('es determinista con el mismo seed', () {
    expect(generarCodigoSala(Random(7)), generarCodigoSala(Random(7)));
  });
}
```

- [ ] **Step 2: Ejecutar y ver que falla**

Run: `flutter test test/online/sala_codigo_test.dart`
Expected: FAIL — target of URI doesn't exist.

- [ ] **Step 3: Implementar**

```dart
// lib/managers/sala_codigo.dart
import 'dart:math';

/// Alfabeto sin caracteres ambiguos (sin O/0, I/1/L) para dictar el código
/// en voz alta sin confusión.
const String kAlfabetoCodigo = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

/// Genera un código de sala de 6 caracteres. La unicidad (no colisión) la
/// garantiza [SalaOnlineManager] reservando el código en la base.
String generarCodigoSala(Random random) {
  final buffer = StringBuffer();
  for (var i = 0; i < 6; i++) {
    buffer.write(kAlfabetoCodigo[random.nextInt(kAlfabetoCodigo.length)]);
  }
  return buffer.toString();
}
```

- [ ] **Step 4: Ejecutar y ver que pasa**

Run: `flutter test test/online/sala_codigo_test.dart`
Expected: PASS.

### Task 3.2: DTOs de sala + EstadoSala

**Files:** Create: `lib/services/sala_gateway.dart` (solo la parte de DTOs en esta task); Test: `test/online/sala_dtos_test.dart`

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/online/sala_dtos_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:impostor_game/services/sala_gateway.dart';

void main() {
  test('JugadorSala round-trip', () {
    const j = JugadorSala(
      uid: 'u1', nombre: 'Ana', numero: 1,
      conectado: true, listo: false, eliminado: false);
    final back = JugadorSala.fromMap('u1', j.toMap());
    expect(back.nombre, 'Ana');
    expect(back.numero, 1);
    expect(back.conectado, true);
    expect(back.eliminado, false);
  });

  test('EstadoSala se parsea por nombre con fallback a lobby', () {
    expect(estadoSalaFromName('votando'), EstadoSala.votando);
    expect(estadoSalaFromName('basura'), EstadoSala.lobby);
  });

  test('RolPrivado guarda null para impostor', () {
    const rol = RolPrivado(esImpostor: true, personajeVisto: null);
    final back = RolPrivado.fromMap(rol.toMap());
    expect(back.esImpostor, true);
    expect(back.personajeVisto, null);
  });
}
```

- [ ] **Step 2: Ejecutar y ver que falla**

Run: `flutter test test/online/sala_dtos_test.dart`
Expected: FAIL — URI no existe.

- [ ] **Step 3: Implementar DTOs + enum (parte 1 de sala_gateway.dart)**

```dart
// lib/services/sala_gateway.dart

/// Fases de una sala online. El nombre del enum se persiste en RTDB.
enum EstadoSala {
  lobby,
  revelando,
  discusion,
  votando,
  resultado,
  finalizada,
  abandonada,
}

EstadoSala estadoSalaFromName(String? name) =>
    EstadoSala.values.firstWhere((e) => e.name == name,
        orElse: () => EstadoSala.lobby);

/// Un jugador tal como vive en /salas/{codigo}/jugadores/{uid}.
class JugadorSala {
  const JugadorSala({
    required this.uid,
    required this.nombre,
    required this.numero,
    required this.conectado,
    required this.listo,
    required this.eliminado,
  });

  final String uid;
  final String nombre;
  final int numero;
  final bool conectado;
  final bool listo;
  final bool eliminado;

  Map<String, Object?> toMap() => {
        'nombre': nombre,
        'numero': numero,
        'conectado': conectado,
        'listo': listo,
        'eliminado': eliminado,
      };

  factory JugadorSala.fromMap(String uid, Map<String, dynamic> m) => JugadorSala(
        uid: uid,
        nombre: (m['nombre'] as String?) ?? '',
        numero: (m['numero'] as int?) ?? 0,
        conectado: (m['conectado'] as bool?) ?? false,
        listo: (m['listo'] as bool?) ?? false,
        eliminado: (m['eliminado'] as bool?) ?? false,
      );

  JugadorSala copyWith({bool? conectado, bool? listo, bool? eliminado, String? nombre}) =>
      JugadorSala(
        uid: uid,
        nombre: nombre ?? this.nombre,
        numero: numero,
        conectado: conectado ?? this.conectado,
        listo: listo ?? this.listo,
        eliminado: eliminado ?? this.eliminado,
      );
}

/// Rol privado de un jugador: vive solo en /salas/{codigo}/privado/{uid}.
class RolPrivado {
  const RolPrivado({required this.esImpostor, required this.personajeVisto});
  final bool esImpostor;
  final String? personajeVisto; // null si es impostor

  Map<String, Object?> toMap() =>
      {'esImpostor': esImpostor, 'personajeVisto': personajeVisto};

  factory RolPrivado.fromMap(Map<String, dynamic> m) => RolPrivado(
        esImpostor: (m['esImpostor'] as bool?) ?? false,
        personajeVisto: m['personajeVisto'] as String?,
      );
}
```

- [ ] **Step 4: Ejecutar y ver que pasa**

Run: `flutter test test/online/sala_dtos_test.dart`
Expected: PASS.

### Task 3.3: Predicados de fase (puros)

**Files:** Modify: `lib/managers/sala_online_manager.dart` (crear archivo con solo las funciones puras por ahora); Test: añadir a `test/online/sala_dtos_test.dart` o nuevo. Usar nuevo: `test/online/sala_predicados_test.dart`.

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/online/sala_predicados_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:impostor_game/services/sala_gateway.dart';
import 'package:impostor_game/managers/sala_predicados.dart';

JugadorSala j(String uid, {bool conectado = true, bool listo = false, bool eliminado = false}) =>
    JugadorSala(uid: uid, nombre: uid, numero: 1,
        conectado: conectado, listo: listo, eliminado: eliminado);

void main() {
  test('puedeIniciar requiere >=3 conectados', () {
    expect(puedeIniciar([j('a'), j('b')]), false);
    expect(puedeIniciar([j('a'), j('b'), j('c')]), true);
  });

  test('todosVotaron ignora eliminados y desconectados', () {
    final jugadores = [
      j('a'), j('b'), j('c', eliminado: true), j('d', conectado: false),
    ];
    // Solo a y b son vivos+conectados → faltan votos.
    expect(todosVotaron(jugadores, {'a': 'b'}), false);
    expect(todosVotaron(jugadores, {'a': 'b', 'b': 'a'}), true);
  });
}
```

- [ ] **Step 2: Ejecutar y ver que falla**

Run: `flutter test test/online/sala_predicados_test.dart`
Expected: FAIL — URI no existe.

- [ ] **Step 3: Implementar**

```dart
// lib/managers/sala_predicados.dart
import '../services/sala_gateway.dart';

/// Solo cuentan los jugadores vivos (no eliminados) y conectados.
List<JugadorSala> activos(List<JugadorSala> jugadores) =>
    jugadores.where((j) => j.conectado && !j.eliminado).toList();

bool puedeIniciar(List<JugadorSala> jugadores) =>
    activos(jugadores).length >= 3;

/// True cuando todos los vivos+conectados ya emitieron su voto.
bool todosVotaron(List<JugadorSala> jugadores, Map<String, String> votos) {
  final pendientes = activos(jugadores).where((j) => !votos.containsKey(j.uid));
  return activos(jugadores).isNotEmpty && pendientes.isEmpty;
}
```

- [ ] **Step 4: Ejecutar y ver que pasa**

Run: `flutter test test/online/sala_predicados_test.dart`
Expected: PASS.

---

## Phase 4 — SalaGateway seam (interfaz + real + fake)

Produce: una capa de I/O RTDB intercambiable. La real envuelve `firebase_database`; la fake es en memoria para tests.

### Task 4.1: Interfaz SalaGateway

**Files:** Modify: `lib/services/sala_gateway.dart` (añadir la interfaz al final)

- [ ] **Step 1: Añadir la interfaz**

Al final de `lib/services/sala_gateway.dart`:
```dart
/// Seam sobre la I/O de Realtime Database. Permite testear la lógica de
/// salas con una implementación en memoria. Las rutas son relativas a la
/// raíz, ej. 'salas/ABC123/meta'.
abstract class SalaGateway {
  /// Lee un nodo una vez. Devuelve null si no existe.
  Future<Map<String, dynamic>?> leerUna(String ruta);

  /// Sobrescribe el valor en [ruta].
  Future<void> escribir(String ruta, Object? valor);

  /// Merge parcial de campos en [ruta].
  Future<void> actualizar(String ruta, Map<String, Object?> valores);

  /// Stream del nodo en [ruta] (mapa o null), emitiendo en cada cambio.
  Stream<Map<String, dynamic>?> observar(String ruta);

  /// Reserva [ruta] solo si NO existe (transacción). true si la reservó.
  Future<bool> reservarSiAusente(String ruta, Object valor);

  /// Programa una escritura automática cuando el cliente se desconecte.
  Future<void> alDesconectar(String ruta, Object? valor);

  /// Cancela una escritura onDisconnect previamente registrada en [ruta].
  Future<void> cancelarAlDesconectar(String ruta);
}
```

- [ ] **Step 2: Verificar que compila**

Run: `flutter analyze lib/services/sala_gateway.dart`
Expected: 0 issues.

### Task 4.2: FakeSalaGateway (para tests)

**Files:** Create: `test/online/fake_sala_gateway.dart`

- [ ] **Step 1: Implementar la fake en memoria**

```dart
// test/online/fake_sala_gateway.dart
import 'dart:async';
import 'package:impostor_game/services/sala_gateway.dart';

/// Implementación en memoria de [SalaGateway] para tests. Guarda un árbol
/// de mapas anidados por ruta 'a/b/c' y notifica a los observadores.
class FakeSalaGateway implements SalaGateway {
  final Map<String, dynamic> _root = {};
  final Map<String, List<StreamController<Map<String, dynamic>?>>> _watchers = {};
  final Map<String, Object?> onDisconnects = {};

  Map<String, dynamic> get raiz => _root;

  List<String> _seg(String ruta) => ruta.split('/').where((s) => s.isNotEmpty).toList();

  Map<String, dynamic>? _leer(List<String> seg) {
    dynamic node = _root;
    for (final s in seg) {
      if (node is Map && node.containsKey(s)) {
        node = node[s];
      } else {
        return null;
      }
    }
    if (node is Map) return Map<String, dynamic>.from(node);
    return null;
  }

  void _set(List<String> seg, Object? valor) {
    if (seg.isEmpty) return;
    Map<String, dynamic> node = _root;
    for (var i = 0; i < seg.length - 1; i++) {
      node = (node[seg[i]] ??= <String, dynamic>{}) as Map<String, dynamic>;
    }
    if (valor == null) {
      node.remove(seg.last);
    } else {
      node[seg.last] = valor;
    }
  }

  void _notify(String ruta) {
    // Notifica a la ruta exacta y a sus ancestros (cambios propagan hacia arriba).
    final seg = _seg(ruta);
    for (var i = seg.length; i >= 0; i--) {
      final prefijo = seg.sublist(0, i).join('/');
      final cs = _watchers[prefijo];
      if (cs != null) {
        final snap = _leer(_seg(prefijo));
        for (final c in cs) {
          if (!c.isClosed) c.add(snap);
        }
      }
    }
  }

  @override
  Future<Map<String, dynamic>?> leerUna(String ruta) async => _leer(_seg(ruta));

  @override
  Future<void> escribir(String ruta, Object? valor) async {
    _set(_seg(ruta), valor);
    _notify(ruta);
  }

  @override
  Future<void> actualizar(String ruta, Map<String, Object?> valores) async {
    valores.forEach((k, v) => _set(_seg('$ruta/$k'), v));
    _notify(ruta);
  }

  @override
  Stream<Map<String, dynamic>?> observar(String ruta) {
    final c = StreamController<Map<String, dynamic>?>.broadcast();
    (_watchers[ruta] ??= []).add(c);
    scheduleMicrotask(() {
      if (!c.isClosed) c.add(_leer(_seg(ruta)));
    });
    return c.stream;
  }

  @override
  Future<bool> reservarSiAusente(String ruta, Object valor) async {
    if (_leer(_seg(ruta)) != null) return false;
    final seg = _seg(ruta);
    // Para nodos hoja que no son mapas, guardamos directo.
    if (valor is Map) {
      _set(seg, Map<String, dynamic>.from(valor));
    } else {
      _set(seg, valor);
    }
    _notify(ruta);
    return true;
  }

  @override
  Future<void> alDesconectar(String ruta, Object? valor) async {
    onDisconnects[ruta] = valor;
  }

  @override
  Future<void> cancelarAlDesconectar(String ruta) async {
    onDisconnects.remove(ruta);
  }

  /// Helper de test: simula que este cliente se desconectó.
  Future<void> dispararDesconexion() async {
    for (final e in onDisconnects.entries) {
      _set(_seg(e.key), e.value);
      _notify(e.key);
    }
  }
}
```
Nota: `reservarSiAusente` para un valor no-mapa (ej. un timestamp en `codigos/ABC`) guarda el valor crudo; `leerUna` devuelve null para hojas no-mapa, lo cual es suficiente porque solo se chequea existencia vía un wrapper en el manager (ver Task 5).

- [ ] **Step 2: Verificar que compila (sin test aún)**

Run: `flutter analyze test/online/fake_sala_gateway.dart`
Expected: 0 issues.

### Task 4.3: FirebaseSalaGateway (real)

**Files:** Create: `lib/services/firebase_sala_gateway.dart`

- [ ] **Step 1: Implementar**

```dart
// lib/services/firebase_sala_gateway.dart
import 'package:firebase_database/firebase_database.dart';
import 'sala_gateway.dart';

class FirebaseSalaGateway implements SalaGateway {
  FirebaseSalaGateway(this._db);
  final FirebaseDatabase _db;

  DatabaseReference _ref(String ruta) => _db.ref(ruta);

  Map<String, dynamic>? _asMap(Object? v) {
    if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
    return null;
  }

  @override
  Future<Map<String, dynamic>?> leerUna(String ruta) async {
    final snap = await _ref(ruta).get();
    if (!snap.exists) return null;
    return _asMap(snap.value);
  }

  @override
  Future<void> escribir(String ruta, Object? valor) =>
      _ref(ruta).set(valor);

  @override
  Future<void> actualizar(String ruta, Map<String, Object?> valores) =>
      _ref(ruta).update(valores);

  @override
  Stream<Map<String, dynamic>?> observar(String ruta) =>
      _ref(ruta).onValue.map((e) =>
          e.snapshot.exists ? _asMap(e.snapshot.value) : null);

  @override
  Future<bool> reservarSiAusente(String ruta, Object valor) async {
    final result = await _ref(ruta).runTransaction((current) {
      if (current != null) return Transaction.abort();
      return Transaction.success(valor);
    });
    return result.committed;
  }

  @override
  Future<void> alDesconectar(String ruta, Object? valor) =>
      _ref(ruta).onDisconnect().set(valor);

  @override
  Future<void> cancelarAlDesconectar(String ruta) =>
      _ref(ruta).onDisconnect().cancel();
}
```

- [ ] **Step 2: Verificar**

Run: `flutter analyze lib/services/firebase_sala_gateway.dart`
Expected: 0 issues.

---

## Phase 5 — SalaOnlineManager (crear / unirse / salir / presencia)

Produce: ciclo de vida de sala, testeado contra la fake.

### Task 5.1: SalaOnlineManager — crear y unirse

**Files:** Create: `lib/managers/sala_online_manager.dart`; Test: `test/online/sala_online_manager_test.dart`

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/online/sala_online_manager_test.dart
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:impostor_game/managers/sala_online_manager.dart';
import 'package:impostor_game/models/configuracion_partida.dart';
import 'package:impostor_game/services/sala_gateway.dart';
import 'fake_sala_gateway.dart';

void main() {
  test('crearSala reserva código, escribe meta y al host como jugador', () async {
    final gw = FakeSalaGateway();
    final mgr = SalaOnlineManager(gateway: gw, uid: 'hostUid', random: Random(1));

    final codigo = await mgr.crearSala(
      nombreHost: 'Ana',
      tematica: 'Animales',
      configuracion: ConfiguracionPartida(),
    );

    expect(codigo.length, 6);
    final meta = await gw.leerUna('salas/$codigo/meta');
    expect(meta!['hostUid'], 'hostUid');
    expect(meta['estado'], EstadoSala.lobby.name);
    final jug = await gw.leerUna('salas/$codigo/jugadores/hostUid');
    expect(jug!['nombre'], 'Ana');
    expect(jug['numero'], 1);
  });

  test('unirseSala agrega al jugador con número incremental', () async {
    final gw = FakeSalaGateway();
    final host = SalaOnlineManager(gateway: gw, uid: 'hostUid', random: Random(1));
    final codigo = await host.crearSala(
      nombreHost: 'Ana', tematica: 'Animales', configuracion: ConfiguracionPartida());

    final guest = SalaOnlineManager(gateway: gw, uid: 'guestUid', random: Random(2));
    await guest.unirseSala(codigo: codigo, nombre: 'Beto');

    final jug = await gw.leerUna('salas/$codigo/jugadores/guestUid');
    expect(jug!['nombre'], 'Beto');
    expect(jug['numero'], 2);
  });

  test('unirseSala a código inexistente lanza', () async {
    final gw = FakeSalaGateway();
    final guest = SalaOnlineManager(gateway: gw, uid: 'g', random: Random(2));
    expect(
      () => guest.unirseSala(codigo: 'ZZZZZZ', nombre: 'Beto'),
      throwsA(isA<SalaException>()),
    );
  });
}
```

- [ ] **Step 2: Ejecutar y ver que falla**

Run: `flutter test test/online/sala_online_manager_test.dart`
Expected: FAIL — URI no existe.

- [ ] **Step 3: Implementar (crear/unirse + presencia)**

```dart
// lib/managers/sala_online_manager.dart
import 'dart:math';
import '../models/configuracion_partida.dart';
import '../services/sala_gateway.dart';
import 'sala_codigo.dart';

class SalaException implements Exception {
  SalaException(this.message);
  final String message;
  @override
  String toString() => 'SalaException: $message';
}

/// Maneja el ciclo de vida de una sala online desde la perspectiva de UN
/// cliente (sea host o invitado). No corre la lógica de juego (eso es
/// [RondaOnlineSync]); solo crea/une/sale y mantiene presencia.
class SalaOnlineManager {
  SalaOnlineManager({
    required SalaGateway gateway,
    required this.uid,
    Random? random,
  })  : _gw = gateway,
        _random = random ?? Random();

  final SalaGateway _gw;
  final String uid;
  final Random _random;

  String? _codigo;
  String? get codigo => _codigo;

  bool get esHost => _codigo != null && _hostUid == uid;
  String? _hostUid;

  /// Crea una sala con código único y deja al host como jugador #1.
  Future<String> crearSala({
    required String nombreHost,
    required String tematica,
    required ConfiguracionPartida configuracion,
  }) async {
    String? codigo;
    for (var intento = 0; intento < 6; intento++) {
      final candidato = generarCodigoSala(_random);
      final reservado =
          await _gw.reservarSiAusente('codigos/$candidato', {'host': uid});
      if (reservado) {
        codigo = candidato;
        break;
      }
    }
    if (codigo == null) {
      throw SalaException('No se pudo generar un código único, reintenta');
    }

    await _gw.escribir('salas/$codigo/meta', {
      'hostUid': uid,
      'estado': EstadoSala.lobby.name,
      'rondaActual': 1,
      'tematica': tematica,
      'configJson': configuracion.toJson(),
      'jugadorInicialUid': null,
      'hostConectado': true,
      'createdAt': ServerValuePlaceholder.timestamp,
    });
    await _gw.escribir('salas/$codigo/jugadores/$uid',
        _jugadorMap(nombre: nombreHost, numero: 1));

    _codigo = codigo;
    _hostUid = uid;
    await _configurarPresencia();
    return codigo;
  }

  Future<void> unirseSala({
    required String codigo,
    required String nombre,
  }) async {
    final meta = await _gw.leerUna('salas/$codigo/meta');
    if (meta == null) {
      throw SalaException('La sala "$codigo" no existe');
    }
    if (estadoSalaFromName(meta['estado'] as String?) != EstadoSala.lobby) {
      throw SalaException('La partida ya empezó');
    }
    final jugadores = await _gw.leerUna('salas/$codigo/jugadores') ?? {};
    if (jugadores.length >= 12 && !jugadores.containsKey(uid)) {
      throw SalaException('La sala está llena (máx. 12)');
    }
    final numero = jugadores.containsKey(uid)
        ? (jugadores[uid] as Map)['numero'] as int
        : jugadores.length + 1;

    await _gw.escribir('salas/$codigo/jugadores/$uid',
        _jugadorMap(nombre: nombre, numero: numero));

    _codigo = codigo;
    _hostUid = meta['hostUid'] as String?;
    await _configurarPresencia();
  }

  Map<String, Object?> _jugadorMap({required String nombre, required int numero}) => {
        'nombre': nombre,
        'numero': numero,
        'conectado': true,
        'listo': false,
        'eliminado': false,
      };

  Future<void> _configurarPresencia() async {
    final c = _codigo!;
    await _gw.alDesconectar('salas/$c/jugadores/$uid/conectado', false);
    if (esHost) {
      // Si el host se cae, la sala se marca abandonada.
      await _gw.alDesconectar('salas/$c/meta/estado', EstadoSala.abandonada.name);
      await _gw.alDesconectar('salas/$c/meta/hostConectado', false);
    }
  }

  Future<void> marcarListo(bool listo) =>
      _gw.actualizar('salas/$_codigo/jugadores/$uid', {'listo': listo});

  Future<void> cambiarNombre(String nombre) =>
      _gw.actualizar('salas/$_codigo/jugadores/$uid', {'nombre': nombre});

  /// Sale de la sala. Si es host, marca la sala abandonada.
  Future<void> salir() async {
    final c = _codigo;
    if (c == null) return;
    await _gw.cancelarAlDesconectar('salas/$c/jugadores/$uid/conectado');
    if (esHost) {
      await _gw.actualizar('salas/$c/meta', {
        'estado': EstadoSala.abandonada.name,
        'hostConectado': false,
      });
    } else {
      await _gw.actualizar('salas/$c/jugadores/$uid', {'conectado': false});
    }
    _codigo = null;
    _hostUid = null;
  }
}

/// Marcador para el timestamp del servidor. En la implementación real se
/// reemplaza por ServerValue.timestamp; en la fake queda como un entero.
class ServerValuePlaceholder {
  static const Object timestamp = 0;
}
```
Nota: para `createdAt`, usar `ServerValue.timestamp` real en producción. Para no acoplar el manager a firebase_database, se define `ServerValuePlaceholder.timestamp = 0`; en `FirebaseSalaGateway.escribir` no se transforma (createdAt = 0 es aceptable en V1, o reemplazar por `DateTime.now().millisecondsSinceEpoch` calculado en el cliente). **Decisión V1:** usar `0` (no se usa createdAt para lógica, solo orden informativo).

- [ ] **Step 4: Ejecutar y ver que pasa**

Run: `flutter test test/online/sala_online_manager_test.dart`
Expected: PASS (3 tests).

### Task 5.2: Observadores de sala (streams)

**Files:** Modify: `lib/managers/sala_online_manager.dart`; Test: añadir a `test/online/sala_online_manager_test.dart`

- [ ] **Step 1: Escribir el test que falla**

Añadir al `main()` del test:
```dart
  test('observarJugadores emite la lista actual', () async {
    final gw = FakeSalaGateway();
    final host = SalaOnlineManager(gateway: gw, uid: 'h', random: Random(1));
    final codigo = await host.crearSala(
        nombreHost: 'Ana', tematica: 'Animales', configuracion: ConfiguracionPartida());

    final emisiones = <List<JugadorSala>>[];
    final sub = host.observarJugadores(codigo).listen(emisiones.add);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final guest = SalaOnlineManager(gateway: gw, uid: 'g', random: Random(2));
    await guest.unirseSala(codigo: codigo, nombre: 'Beto');
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(emisiones.last.map((j) => j.nombre), containsAll(['Ana', 'Beto']));
    await sub.cancel();
  });
```

- [ ] **Step 2: Ejecutar y ver que falla**

Run: `flutter test test/online/sala_online_manager_test.dart`
Expected: FAIL — `observarJugadores` no existe.

- [ ] **Step 3: Implementar**

Añadir a `SalaOnlineManager`:
```dart
  Stream<List<JugadorSala>> observarJugadores(String codigo) =>
      _gw.observar('salas/$codigo/jugadores').map((m) {
        if (m == null) return <JugadorSala>[];
        final lista = [
          for (final e in m.entries)
            JugadorSala.fromMap(e.key, (e.value as Map).cast<String, dynamic>()),
        ]..sort((a, b) => a.numero.compareTo(b.numero));
        return lista;
      });

  Stream<Map<String, dynamic>?> observarMeta(String codigo) =>
      _gw.observar('salas/$codigo/meta');

  Stream<Map<String, dynamic>?> observarPublico(String codigo) =>
      _gw.observar('salas/$codigo/publico');
```
Importar `package:impostor_game/services/sala_gateway.dart` ya está implícito por el mismo paquete; añadir `import '../services/sala_gateway.dart';` si falta (ya está en el import del manager).

- [ ] **Step 4: Ejecutar y ver que pasa**

Run: `flutter test test/online/sala_online_manager_test.dart`
Expected: PASS (4 tests).

---

## Phase 6 — RondaOnlineSync (host: PartidaManager ⇄ RTDB)

Produce: el host asigna roles y publica; el conteo de votos elimina y verifica fin. Testeado contra la fake.

### Task 6.1: Host inicia ronda (asigna roles, publica privado/publico)

**Files:** Create: `lib/managers/ronda_online_sync.dart`; Test: `test/online/ronda_online_sync_test.dart`

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/online/ronda_online_sync_test.dart
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:impostor_game/managers/partida_manager.dart';
import 'package:impostor_game/managers/ronda_online_sync.dart';
import 'package:impostor_game/models/configuracion_partida.dart';
import 'package:impostor_game/services/sala_gateway.dart';
import 'fake_sala_gateway.dart';

Future<void> _seedLobby(FakeSalaGateway gw, String codigo) async {
  await gw.escribir('salas/$codigo/meta', {
    'hostUid': 'h', 'estado': EstadoSala.lobby.name, 'rondaActual': 1,
    'tematica': 'Animales', 'configJson': ConfiguracionPartida().toJson(),
  });
  await gw.escribir('salas/$codigo/jugadores', {
    'h': {'nombre': 'Ana', 'numero': 1, 'conectado': true, 'listo': true, 'eliminado': false},
    'g1': {'nombre': 'Beto', 'numero': 2, 'conectado': true, 'listo': true, 'eliminado': false},
    'g2': {'nombre': 'Caro', 'numero': 3, 'conectado': true, 'listo': true, 'eliminado': false},
  });
}

void main() {
  test('iniciarPartida asigna 1 impostor y escribe /privado por jugador', () async {
    final gw = FakeSalaGateway();
    const codigo = 'ABC234';
    await _seedLobby(gw, codigo);

    final host = RondaOnlineSync(
      gateway: gw, codigo: codigo, uid: 'h',
      manager: PartidaManager(random: Random(1)),
    );
    await host.iniciarPartida(personajeSecreto: 'León');

    // Cada jugador tiene su rol privado.
    final privados = <RolPrivado>[];
    for (final u in ['h', 'g1', 'g2']) {
      final m = await gw.leerUna('salas/$codigo/privado/$u');
      privados.add(RolPrivado.fromMap(m!));
    }
    expect(privados.where((r) => r.esImpostor).length, 1);
    // El civil ve el personaje; el impostor no.
    for (final r in privados) {
      if (r.esImpostor) {
        expect(r.personajeVisto, null);
      } else {
        expect(r.personajeVisto, 'León');
      }
    }
    // Estado pasó a revelando y se eligió quién empieza.
    final meta = await gw.leerUna('salas/$codigo/meta');
    expect(meta!['estado'], EstadoSala.revelando.name);
    expect(meta['jugadorInicialUid'], isNotNull);
  });
}
```

- [ ] **Step 2: Ejecutar y ver que falla**

Run: `flutter test test/online/ronda_online_sync_test.dart`
Expected: FAIL — URI no existe.

- [ ] **Step 3: Implementar iniciarPartida**

```dart
// lib/managers/ronda_online_sync.dart
import '../managers/partida_manager.dart';
import '../models/partida.dart';
import '../services/sala_gateway.dart';

/// Sincroniza una ronda entre el motor de juego del host ([PartidaManager])
/// y Realtime Database. Solo el host crea una instancia "activa" que escribe;
/// los clientes usan los streams de [SalaOnlineManager] para leer.
class RondaOnlineSync {
  RondaOnlineSync({
    required SalaGateway gateway,
    required this.codigo,
    required this.uid,
    required PartidaManager manager,
  })  : _gw = gateway,
        _manager = manager;

  final SalaGateway _gw;
  final String codigo;
  final String uid;
  final PartidaManager _manager;

  String _meta(String k) => 'salas/$codigo/meta/$k';
  String get _publico => 'salas/$codigo/publico';

  /// HOST: lee el roster del lobby, crea la Partida con ids=uid, asigna roles,
  /// publica /privado/{uid} y pasa a 'revelando'.
  Future<void> iniciarPartida({required String personajeSecreto}) async {
    final jugRaw = await _gw.leerUna('salas/$codigo/jugadores') ?? {};
    final metaRaw = await _gw.leerUna('salas/$codigo/meta') ?? {};

    // Orden estable por número.
    final entries = jugRaw.entries.toList()
      ..sort((a, b) => ((a.value as Map)['numero'] as int)
          .compareTo((b.value as Map)['numero'] as int));
    final uids = [for (final e in entries) e.key];
    final nombres = [for (final e in entries) (e.value as Map)['nombre'] as String];

    final partida = _manager.crearPartida(
      tematica: metaRaw['tematica'] as String? ?? '',
      personajeSecreto: personajeSecreto,
      nombresJugadores: nombres,
      ids: uids,
      configuracion: _manager.partidaActual?.configuracion ?? _configDesdeMeta(metaRaw),
    );
    final ronda = _manager.iniciarRonda();

    // Escribir el rol privado de cada jugador.
    for (final j in partida.jugadores) {
      await _gw.escribir('salas/$codigo/privado/${j.id}', {
        'esImpostor': j.esImpostor,
        'personajeVisto': j.esImpostor ? null : personajeSecreto,
      });
    }

    await _gw.escribir(_publico, _publicoDesdePartida(partida));
    await _gw.actualizar('salas/$codigo/meta', {
      'estado': EstadoSala.revelando.name,
      'jugadorInicialUid': ronda.jugadorInicial?.id,
    });
  }

  ConfiguracionPartida _configDesdeMeta(Map<String, dynamic> meta) =>
      ConfiguracionPartida.fromJson(
          (meta['configJson'] as Map?)?.cast<String, dynamic>() ?? const {});

  Map<String, Object?> _publicoDesdePartida(Partida p) => {
        'jugadoresVivos': [for (final j in p.jugadoresVivos) j.id],
        'conteoVotos': <String, int>{},
        'ganador': null,
        'resultadoRonda': null,
      };
}
```
Añadir el import `import '../models/configuracion_partida.dart';`.

- [ ] **Step 4: Ejecutar y ver que pasa**

Run: `flutter test test/online/ronda_online_sync_test.dart`
Expected: PASS.

### Task 6.2: Transiciones de fase (abrir votación, votar, cerrar/contar)

**Files:** Modify: `lib/managers/ronda_online_sync.dart`; Test: añadir a `test/online/ronda_online_sync_test.dart`

- [ ] **Step 1: Escribir el test que falla**

Añadir:
```dart
  test('votación: todos votan al impostor → lo elimina y publica resultado', () async {
    final gw = FakeSalaGateway();
    const codigo = 'ABC235';
    await _seedLobby(gw, codigo);
    final host = RondaOnlineSync(
      gateway: gw, codigo: codigo, uid: 'h',
      manager: PartidaManager(random: Random(1)));
    await host.iniciarPartida(personajeSecreto: 'León');
    await host.abrirVotacion();

    // Descubrir quién es el impostor por /privado.
    String impostor = 'h';
    for (final u in ['h', 'g1', 'g2']) {
      final m = await gw.leerUna('salas/$codigo/privado/$u');
      if ((m!['esImpostor'] as bool)) impostor = u;
    }
    final votantes = ['h', 'g1', 'g2'];
    for (final v in votantes) {
      await gw.escribir('salas/$codigo/votos/$v', {'objetivoUid': impostor});
    }
    await host.contarVotosYResolver();

    final meta = await gw.leerUna('salas/$codigo/meta');
    expect(meta!['estado'], EstadoSala.resultado.name);
    final pub = await gw.leerUna('salas/$codigo/publico');
    final res = (pub!['resultadoRonda'] as Map);
    expect(res['eliminadoUid'], impostor);
    expect(res['eraImpostor'], true);
    // Civiles ganan (único impostor eliminado).
    expect(pub['ganador'], 'jugadores');
  });
```

- [ ] **Step 2: Ejecutar y ver que falla**

Run: `flutter test test/online/ronda_online_sync_test.dart`
Expected: FAIL — `abrirVotacion`/`contarVotosYResolver` no existen.

- [ ] **Step 3: Implementar**

Añadir a `RondaOnlineSync`:
```dart
  Future<void> abrirVotacion() async {
    await _gw.escribir('salas/$codigo/votos', null); // limpia votos previos
    await _gw.actualizar('salas/$codigo/meta', {'estado': EstadoSala.votando.name});
  }

  Future<void> irADiscusion() =>
      _gw.actualizar('salas/$codigo/meta', {'estado': EstadoSala.discusion.name});

  /// HOST: lee los votos, cuenta, elimina, verifica fin y publica resultado.
  Future<void> contarVotosYResolver() async {
    final votosRaw = await _gw.leerUna('salas/$codigo/votos') ?? {};
    final votos = <String, String>{
      for (final e in votosRaw.entries)
        e.key: (e.value as Map)['objetivoUid'] as String,
    };

    final conteo = _manager.procesarVotacion(votos);
    final config = _manager.partidaActual!.configuracion;
    final eliminadoId =
        _manager.obtenerJugadorEliminado(conteo, config.eliminarEnEmpate);

    bool eraImpostor = false;
    if (eliminadoId != null) {
      final jug = _manager.partidaActual!.jugadores
          .firstWhere((j) => j.id == eliminadoId);
      eraImpostor = jug.esImpostor;
      _manager.eliminarJugador(eliminadoId);
      await _gw.actualizar(
          'salas/$codigo/jugadores/$eliminadoId', {'eliminado': true});
    }
    _manager.finalizarRonda();
    final fin = _manager.verificarFinDeJuego();
    final p = _manager.partidaActual!;

    await _gw.actualizar(_publico, {
      'conteoVotos': conteo,
      'jugadoresVivos': [for (final j in p.jugadoresVivos) j.id],
      'resultadoRonda': {'eliminadoUid': eliminadoId, 'eraImpostor': eraImpostor},
      'ganador': fin ? p.ganador?.name : null,
    });
    await _gw.actualizar('salas/$codigo/meta', {
      'estado': fin ? EstadoSala.finalizada.name : EstadoSala.resultado.name,
    });
  }

  /// HOST: prepara la siguiente ronda (mismos jugadores vivos, nuevo personaje).
  Future<void> siguienteRonda({required String personajeSecreto}) async {
    _manager.siguienteRonda();
    final ronda = _manager.iniciarRonda();
    // Actualizar roles privados solo de los vivos (los eliminados ya no juegan).
    final p = _manager.partidaActual!;
    for (final j in p.jugadoresVivos) {
      await _gw.escribir('salas/$codigo/privado/${j.id}', {
        'esImpostor': j.esImpostor,
        'personajeVisto': j.esImpostor ? null : personajeSecreto,
      });
    }
    await _gw.escribir('salas/$codigo/votos', null);
    await _gw.actualizar(_publico, {
      'jugadoresVivos': [for (final j in p.jugadoresVivos) j.id],
      'conteoVotos': <String, int>{},
      'resultadoRonda': null,
    });
    await _gw.actualizar('salas/$codigo/meta', {
      'estado': EstadoSala.revelando.name,
      'rondaActual': p.rondaActual,
      'jugadorInicialUid': ronda.jugadorInicial?.id,
    });
  }
```
Nota: `siguienteRonda` mantiene el MISMO `personajeSecreto`/impostor de la partida (el impostor no cambia entre rondas, igual que el modo local — la partida se crea una vez). Para una "Nueva partida" completa (re-sortear impostor), se llama de nuevo a `iniciarPartida` tras `_manager.reiniciar()` y recrear; eso lo hace el botón "Nueva partida" del resultado final (Phase 8).

- [ ] **Step 4: Ejecutar y ver que pasa + suite completa**

Run: `flutter test`
Expected: PASS (todos: 58 previos + nuevos).

---

## Phase 7 — Pantallas: entrada Home + Crear + Unirse + Lobby online

Produce: flujo hasta el lobby online, en vivo, en 2 dispositivos.

> Las pantallas reusan el design system existente: `AppScaffold`, `AppButton`/`AppButtonVariant`, `AppType`, `AppColors`, `AppCard`, `AppChip`, `AutoFitTitle`, `AdaptiveAvatarGrid`. Para estilo, **espejar** las pantallas locales equivalentes (`home_screen.dart`, `configurar_partida_screen.dart`, `lobby_screen.dart`). Los `StreamBuilder` usan los streams de `SalaOnlineManager`.

### Task 7.1: Entrada "Jugar online" en Home

**Files:** Modify: `lib/screens/home_screen.dart`

- [ ] **Step 1: Añadir bloque de 2 botones**

En el cuerpo del Home, bajo los botones existentes ("Jugar ahora"/"Continuar"), añadir una sección:
```dart
const SizedBox(height: 24),
Text('JUGAR ONLINE', style: AppType.label.copyWith(color: AppColors.textMuted)),
const SizedBox(height: 12),
AppButton(
  label: 'Crear sala',
  variant: AppButtonVariant.secondary,
  icon: Icons.add_circle_outline,
  onPressed: () => Navigator.of(context).push(
    SlidePageRoute(page: const CrearSalaScreen()),
  ),
),
const SizedBox(height: 12),
AppButton(
  label: 'Unirse con código',
  variant: AppButtonVariant.secondary,
  icon: Icons.login,
  onPressed: () => Navigator.of(context).push(
    SlidePageRoute(page: const UnirseSalaScreen()),
  ),
),
```
Añadir imports: `import 'online/crear_sala_screen.dart';` y `import 'online/unirse_sala_screen.dart';`. Ajustar `icon`/`AppButtonVariant` a la API real de `AppButton` (verificar en `lib/widgets/app_button.dart`).

- [ ] **Step 2: Verificar (con stubs de pantalla)**

Crear stubs mínimos primero (Task 7.2/7.3 crean las reales). Run: `flutter analyze`.
Expected: 0 issues una vez existan `CrearSalaScreen` y `UnirseSalaScreen`.

### Task 7.2: CrearSalaScreen

**Files:** Create: `lib/screens/online/crear_sala_screen.dart`

- [ ] **Step 1: Implementar**

Pantalla con: campo nombre, selector de temática (reusar el patrón de `_cambiarTematica` de `lobby_screen.dart` / lista de `tematicasData.keys`), selector de nº impostores y toggle "eliminar en empate" (reusar de `configurar_partida_screen.dart`). Botón "Crear sala":
```dart
Future<void> _crear() async {
  final firebase = context.read<FirebaseService>();
  final gw = FirebaseSalaGateway(firebase.db);
  final mgr = SalaOnlineManager(gateway: gw, uid: firebase.uid);
  final codigo = await mgr.crearSala(
    nombreHost: _nombre.text.trim(),
    tematica: _tematica,
    configuracion: ConfiguracionPartida(
      numeroImpostores: _numImpostores,
      eliminarEnEmpate: _eliminarEnEmpate,
    ),
  );
  if (!mounted) return;
  Navigator.of(context).pushReplacement(SlidePageRoute(
    page: LobbyOnlineScreen(codigo: codigo, manager: mgr, esHost: true,
        tematica: _tematica),
  ));
}
```
Validar el nombre con `Validators.playerName` antes de crear; mostrar `SnackBar` si hay error o si `crearSala` lanza `SalaException`.
Imports: `firebase_service.dart`, `firebase_sala_gateway.dart`, `sala_online_manager.dart`, `lobby_online_screen.dart`, `configuracion_partida.dart`, `validators.dart`, `tematicas_data.dart`, design system.

- [ ] **Step 2: Verificar**

Run: `flutter analyze` → 0 issues (tras crear LobbyOnlineScreen en 7.4; usar stub mínimo si hace falta).

### Task 7.3: UnirseSalaScreen

**Files:** Create: `lib/screens/online/unirse_sala_screen.dart`

- [ ] **Step 1: Implementar**

Campo de código (6 chars, `textCapitalization: TextCapitalization.characters`, filtro a `kAlfabetoCodigo`) + campo nombre. Botón "Entrar":
```dart
Future<void> _entrar() async {
  final firebase = context.read<FirebaseService>();
  final gw = FirebaseSalaGateway(firebase.db);
  final mgr = SalaOnlineManager(gateway: gw, uid: firebase.uid);
  try {
    await mgr.unirseSala(codigo: _codigo.text.trim().toUpperCase(),
        nombre: _nombre.text.trim());
  } on SalaException catch (e) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message)));
    return;
  }
  if (!mounted) return;
  Navigator.of(context).pushReplacement(SlidePageRoute(
    page: LobbyOnlineScreen(codigo: _codigo.text.trim().toUpperCase(),
        manager: mgr, esHost: false, tematica: null),
  ));
}
```

- [ ] **Step 2: Verificar**

Run: `flutter analyze` → 0 issues.

### Task 7.4: LobbyOnlineScreen (lista en vivo + "Listo" + controles host)

**Files:** Create: `lib/screens/online/lobby_online_screen.dart`

- [ ] **Step 1: Implementar el esqueleto con StreamBuilder de meta (router de fase)**

Esta pantalla es el **router de fases**: escucha `meta.estado` y navega a la pantalla de cada fase. En `lobby` muestra el lobby; cuando `estado` cambia a `revelando`, empuja `RevelarRolOnlineScreen`, etc. Patrón:
```dart
class LobbyOnlineScreen extends StatefulWidget { /* codigo, manager, esHost, tematica */ }

class _LobbyOnlineScreenState extends State<LobbyOnlineScreen> {
  RondaOnlineSync? _sync; // solo host
  EstadoSala _estado = EstadoSala.lobby;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _confirmarSalir(),
      child: StreamBuilder<Map<String, dynamic>?>(
        stream: widget.manager.observarMeta(widget.codigo),
        builder: (context, snap) {
          final meta = snap.data;
          final estado = estadoSalaFromName(meta?['estado'] as String?);
          // Reaccionar a transiciones del host:
          WidgetsBinding.instance.addPostFrameCallback((_) =>
              _onEstado(estado, meta));
          return _buildLobby(context); // el lobby siempre visible de fondo
        },
      ),
    );
  }
  // _onEstado: si estado==abandonada → diálogo "el host salió" + pop a Home.
  //            si estado!=lobby → navegar a la pantalla de fase (pushReplacement
  //            dentro de un Navigator interno, o manejar fases con un switch en build).
}
```
**Decisión de arquitectura de navegación:** en vez de múltiples pushes, el lobby online renderiza la **fase actual con un `switch (estado)`** en su `build` (una sola pantalla que cambia de cuerpo). Esto evita condiciones de carrera con el back. El cuerpo:
```dart
Widget _cuerpoSegunFase(EstadoSala estado, Map<String, dynamic>? meta) {
  switch (estado) {
    case EstadoSala.lobby: return _LobbyView(...);
    case EstadoSala.revelando: return RevelarRolOnlineView(codigo, manager, sync: _sync, esHost: widget.esHost);
    case EstadoSala.discusion: return DiscusionOnlineView(...);
    case EstadoSala.votando: return VotacionOnlineView(...);
    case EstadoSala.resultado: return ResultadoRondaOnlineView(...);
    case EstadoSala.finalizada: return ResultadoFinalOnlineView(...);
    case EstadoSala.abandonada: return _AbandonadaView();
  }
}
```
Las "View" son widgets (no Screens con Scaffold propio) — cada una recibe `codigo`, `manager`, y para el host el `_sync`. Renderizan con `AppScaffold`/cuerpo según el design system.

- [ ] **Step 2: _LobbyView — lista en vivo + Listo + Empezar**

`StreamBuilder<List<JugadorSala>>` sobre `manager.observarJugadores(codigo)`:
- Muestra el código grande (con botón copiar), `AdaptiveAvatarGrid` o lista de jugadores con check de "listo" y badge "conectado".
- Botón "Listo"/"No listo" (toca `manager.marcarListo`).
- Solo el host: botón "Empezar partida", habilitado si `puedeIniciar(jugadores)`. Al tocarlo:
```dart
Future<void> _empezar(List<JugadorSala> jugadores) async {
  final personajes = tematicasData[widget.tematica]!; // o custom repo
  final secreto = personajes[Random().nextInt(personajes.length)].nombre;
  _sync ??= RondaOnlineSync(
    gateway: FirebaseSalaGateway(context.read<FirebaseService>().db),
    codigo: widget.codigo, uid: context.read<FirebaseService>().uid,
    manager: PartidaManager());
  await _sync!.iniciarPartida(personajeSecreto: secreto);
}
```
Guardar `_personajeSecreto`/`_sync` en el state del lobby para reusar en siguientes rondas.

- [ ] **Step 3: Verificar en 2 dispositivos**

Run: `flutter run -d emulator-5554` (host) y en paralelo `flutter run -d <cel-fisico>` (invitado).
Expected: crear sala en uno, unirse con el código en el otro, ver ambos nombres en vivo, marcar "listo", el host ve "Empezar partida" habilitado con 3 jugadores (añadir un 3º o probar con 2 emuladores + web).

---

## Phase 8 — Pantallas de ronda + reglas RTDB

Produce: ronda completa online en varios dispositivos, con anti-trampa real activado.

### Task 8.1: RevelarRolOnlineView

**Files:** Create: `lib/screens/online/revelar_rol_online_screen.dart` (exporta el widget `RevelarRolOnlineView`)

- [ ] **Step 1: Implementar**

`StreamBuilder` sobre `manager._gw.observar('salas/$codigo/privado/$uid')` — exponer en `SalaOnlineManager` un `Stream<RolPrivado?> observarMiRol(codigo, uid)`:
```dart
// añadir a SalaOnlineManager:
Stream<RolPrivado?> observarMiRol(String codigo) =>
    _gw.observar('salas/$codigo/privado/$uid')
       .map((m) => m == null ? null : RolPrivado.fromMap(m));
```
La vista muestra la carta reusando el look de `revelar_roles_screen.dart` (anti-spoiler por defecto, color opcional según `prefs.colorfulReveal`): si `esImpostor` → "Eres el IMPOSTOR"; si no → personaje (`personajeVisto`). Botón "Entendido" → marca al jugador listo (`manager.marcarListo(true)`).
Solo el host ve un botón extra "Todos listos → Discusión" (habilitado cuando todos los activos están `listo`), que llama `_sync.irADiscusion()`.

- [ ] **Step 2: Verificar** — `flutter analyze` 0 issues.

### Task 8.2: DiscusionOnlineView

**Files:** Add `DiscusionOnlineView` (puede ir en `lobby_online_screen.dart` o archivo propio `discusion_online_view.dart`)

- [ ] **Step 1: Implementar**

Lee `meta.jugadorInicialUid` + la lista de jugadores → muestra "🗣️ Empieza: **{nombre}**" + temática. Solo el host: botón "Abrir votación" → `_sync.abrirVotacion()`.

- [ ] **Step 2: Verificar** — `flutter analyze` 0 issues.

### Task 8.3: VotacionOnlineView (voto secreto individual)

**Files:** Create: `lib/screens/online/votacion_online_screen.dart` (exporta `VotacionOnlineView`)

- [ ] **Step 1: Implementar**

- `StreamBuilder<List<JugadorSala>>` → rejilla `AdaptiveAvatarGrid` con **solo vivos** (`!eliminado`).
- Tocar una cara → hoja de confirmación in-screen (reusar la UX ya pulida de `votacion_screen.dart`: `AnimatedPositioned` + scrim + "¿Votar por X?"). Confirmar escribe el voto:
```dart
Future<void> _votar(String objetivoUid) async {
  await context.read<SalaOnlineManager>()... // o el manager pasado por params
  await gw.escribir('salas/$codigo/votos/$miUid', {'objetivoUid': objetivoUid});
  setState(() => _yaVote = true);
}
```
- Exponer en `SalaOnlineManager`: `Future<void> votar(String codigo, String objetivoUid)` que escribe `salas/$codigo/votos/$uid`. Y `Stream<Map<String,dynamic>?> observarVotos(codigo)` (solo lo usa el host).
- Tras votar: muestra "Ya votaste · esperando a los demás" + progreso "X/Y" (host y todos pueden ver el conteo de cuántos votaron desde el stream de votos si las reglas lo permiten; **decisión:** el progreso "cuántos votaron" se publica por el host en `publico.votosEmitidos` (un entero), para no exponer `votos` a los clientes).
- **Solo host:** botón "Cerrar votación" (forzar) → `_sync.contarVotosYResolver()`. Además, el host corre un listener: cuando `todosVotaron(jugadores, votos)` → llama `contarVotosYResolver()` automáticamente. Implementar en la vista del host un `StreamBuilder`/listener combinado sobre jugadores+votos.

- [ ] **Step 2: Host auto-cierra cuando todos votaron**

En la vista del host, suscribirse a `observarVotos` + jugadores; en cada emisión, si `todosVotaron(...)` y aún en `votando`, llamar `contarVotosYResolver()` una sola vez (guardar flag `_resuelto`).

- [ ] **Step 3: Verificar** — `flutter analyze` 0 issues.

### Task 8.4: ResultadoRondaOnlineView + ResultadoFinalOnlineView

**Files:** Create: `lib/screens/online/resultado_ronda_online_screen.dart`

- [ ] **Step 1: Implementar resultado de ronda**

Lee `publico.resultadoRonda` + jugadores → muestra "Eliminado: {nombre}" + "Era impostor: sí/no" + jugadores vivos restantes. Solo host: botón "Siguiente ronda" → `_sync.siguienteRonda(personajeSecreto: <mismo de la partida>)`. (El personaje/impostor no cambian dentro de una partida.)

- [ ] **Step 2: Implementar resultado final**

Cuando `meta.estado == finalizada`: mostrar ganador (`publico.ganador`) y ranking. Reusar el estilo de `resultado_final_screen.dart`. Solo host: "Nueva partida" → `_manager.reiniciar()` + volver a `lobby` (`meta.estado=lobby`, limpiar `privado`/`votos`/`publico`) para re-sortear con el mismo grupo; o "Cerrar sala" → `manager.salir()` + volver a Home.

- [ ] **Step 3: Verificar** — `flutter analyze` 0 issues.

### Task 8.5: Reglas de seguridad RTDB

**Files:** Create: `database.rules.json`

- [ ] **Step 1: Escribir las reglas**

```json
{
  "rules": {
    "codigos": {
      "$codigo": {
        ".read": "auth != null",
        ".write": "auth != null && !data.exists()"
      }
    },
    "salas": {
      "$codigo": {
        ".read": "auth != null && data.child('jugadores').child(auth.uid).exists()",
        "meta": {
          ".write": "auth != null && (!data.exists() || data.child('hostUid').val() === auth.uid)"
        },
        "publico": {
          ".write": "auth != null && root.child('salas').child($codigo).child('meta').child('hostUid').val() === auth.uid"
        },
        "jugadores": {
          "$uid": {
            ".write": "auth != null && (auth.uid === $uid || root.child('salas').child($codigo).child('meta').child('hostUid').val() === auth.uid)"
          }
        },
        "privado": {
          "$uid": {
            ".read": "auth != null && auth.uid === $uid",
            ".write": "auth != null && root.child('salas').child($codigo).child('meta').child('hostUid').val() === auth.uid"
          }
        },
        "votos": {
          ".read": "auth != null && root.child('salas').child($codigo).child('meta').child('hostUid').val() === auth.uid",
          "$uid": {
            ".write": "auth != null && auth.uid === $uid && root.child('salas').child($codigo).child('meta').child('estado').val() === 'votando'"
          }
        }
      }
    }
  }
}
```

- [ ] **Step 2: Publicar y verificar**

El usuario pega `database.rules.json` en Firebase Console → Realtime Database → Rules → Publish.
Verificar el flujo completo en 2-3 dispositivos: crear → unirse → empezar → cada quien ve SU rol (intentar leer `privado` de otro uid desde la consola/otra cuenta debe fallar) → discusión → votar todos → resultado → siguiente ronda → fin.

- [ ] **Step 3: Suite + analyze**

Run: `flutter test && flutter analyze`
Expected: PASS, 0 issues.

---

## Phase 9 — Reconexión, host se va, pulido

### Task 9.1: Guardar sala activa + reconexión

**Files:** Modify: `lib/services/preferences_service.dart`, `lib/screens/home_screen.dart`

- [ ] **Step 1: Persistir el código de sala activo**

Añadir en `PreferencesService` getters/setters `salaActivaCodigo` (key `online.sala_activa`). Al crear/unirse, guardarlo; al salir/abandonar, limpiarlo.

- [ ] **Step 2: Botón "Reconectar a la sala" en Home**

Si `prefs.salaActivaCodigo != null`, mostrar en Home un botón "Reconectar a sala {codigo}" que verifica que la sala sigue viva (`meta.estado != abandonada/finalizada`) y reentra a `LobbyOnlineScreen` (que renderiza la fase actual). Si la sala ya no existe, limpiar la pref y avisar.

- [ ] **Step 3: Verificar** — cerrar la app de un invitado a mitad de ronda y reabrir → vuelve a su fase con su rol. `flutter analyze` 0 issues.

### Task 9.2: Manejo de "host se fue"

**Files:** Modify: `lib/screens/online/lobby_online_screen.dart`

- [ ] **Step 1: Implementar**

En `_onEstado`, si `estado == abandonada`: mostrar diálogo "El anfitrión salió de la sala" + botón "Volver al inicio" → limpiar pref → `Navigator.popUntil` a Home. (La fase `abandonada` se setea por el `onDisconnect` del host configurado en `SalaOnlineManager._configurarPresencia`.)

- [ ] **Step 2: Verificar en 2 dispositivos** — cerrar la app del host a mitad → el invitado ve el aviso y vuelve a Home.

### Task 9.3: Actualizar CLAUDE.md

**Files:** Modify: `CLAUDE.md`

- [ ] **Step 1:** Mover "Modo Multijugador Online" de "Pendientes" a "Completadas" con resumen real (Firebase RTDB host-authoritative, `SalaGateway` seam, pantallas en `lib/screens/online/`). Documentar que `google-services.json` no está en el repo y cómo regenerarlo.

---

## Commit final (un solo commit)

> Preferencia del usuario: **un solo commit, autor Dietri-Diaz, sin co-autor.** Ver memoria `feedback_git_single_commit`.

- [ ] **Step 1: Verificar todo verde**

Run: `flutter test && flutter analyze`
Expected: todos los tests PASS, 0 issues.

- [ ] **Step 2: Stage de todo lo del feature (sin google-services.json ni android local)**

```bash
git -C . add lib/ test/ docs/ database.rules.json pubspec.yaml pubspec.lock .gitignore android/app/build.gradle.kts android/settings.gradle.kts CLAUDE.md
git -C . status   # confirmar que google-services.json NO aparece (ignorado)
```

- [ ] **Step 3: Commit único (squash si hubo commits intermedios)**

Si durante la ejecución se hicieron commits intermedios, aplastarlos en uno solo antes de pushear (`git reset --soft <base>` y un commit), o usar `commit-tree`. Mensaje:
```
feat(online): modo Sala Online por código (Firebase RTDB host-authoritative)
```
Autor = identidad git ya configurada (Dietri-Diaz). NO añadir trailer Co-Authored-By.

- [ ] **Step 4: Push**

Run: `git -C . push origin main`
Expected: actualiza `main` en GitHub con el feature en un solo commit.

---

## Self-review (cobertura del spec)

- Backend Firebase RTDB + auth anónima → Phase 0. ✔
- Host-authoritative reusando PartidaManager → Phase 2 (ids) + Phase 6 (sync). ✔
- Anti-trampa `/privado/{uid}` + reglas → Phase 6.1 (escritura) + Phase 8.5 (reglas). ✔
- Crear/unirse por código único → Phase 3.1 + Phase 5.1. ✔
- Lobby en vivo + "Listo" → Phase 7.4. ✔
- Revelación por dispositivo (solo tu rol) → Phase 8.1. ✔
- "Quién empieza" → reusado en Phase 6.1 (`iniciarRonda` ya lo calcula). ✔
- Votación secreta individual + cierre por "todos votaron" + forzar host → Phase 3.3 (predicado) + Phase 6.2 + Phase 8.3. ✔
- Sin voto unánime en online → las vistas online no incluyen ese modo. ✔
- Resultado + multironda + marcador → Phase 6.2 + Phase 8.4. ✔
- Reconexión simple → Phase 9.1. ✔
- Host se va = sala termina → Phase 5.1 (onDisconnect) + Phase 9.2 (UI). ✔
- Máx 12 / código 6 chars sin ambiguos → Phase 5.1 (límite) + Phase 3.1. ✔
- Setup Firebase + pruebas multi-dispositivo → Phase 0 + smoke tests en 7.4/8.5. ✔
- Modo local intacto → Phase 2 test "sin ids" + suite de 58 tests verde en cada fase. ✔
