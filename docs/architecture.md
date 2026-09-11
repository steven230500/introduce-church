# Arquitectura — introduce_church

Basada en clean architecture con módulos independientes.

---

## Estructura de módulo

```
lib/modules/<feature>/
├── module.dart               ← binds + routes + BlocProvider
├── utils/navigator.dart      ← métodos de navegación estáticos
└── children/<sub-feature>/
    ├── presenter/
    │   ├── page.dart         ← imports + part directives + widget raíz
    │   ├── widgets/
    │   │   └── body.dart     ← part of '../page.dart'
    │   └── cubit/
    │       ├── cubit.dart    ← Model + Cubit (imports + part 'state.dart')
    │       └── state.dart    ← part of 'cubit.dart'
    └── repository/
        └── repository.dart   ← acceso a datos (Supabase / API)
```

---

## Reglas

### 1. BlocProvider va en el módulo, no en la página

```dart
// module.dart ✅
r.child(
  '/login',
  child: (_) => BlocProvider(
    create: (_) => Modular.get<LoginCubit>(),
    child: const LoginPage(),
  ),
);

// page.dart ❌ — nunca crear el cubit aquí
```

### 2. Imports: solo en page.dart

`body.dart` y demás `part` files heredan todos los imports de `page.dart`.
No repetir imports en part files.

```dart
// page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' show Modular; // solo donde se usa Modular.to
import 'cubit/cubit.dart';

part 'widgets/body.dart';
```

### 3. Conflicto context.read

`flutter_modular` y `provider` ambos extienden `BuildContext` con `read<T>()`.
En páginas que usen `Modular.to.navigate` Y `context.read`: importar modular con `show Modular`.

```dart
import 'package:flutter_modular/flutter_modular.dart' show Modular;
```

En module files (no usan `context.read`): import normal de flutter_modular.

### 4. Model dentro del cubit

El modelo de estado va en `cubit.dart`, no en archivo separado.

```dart
// cubit.dart
class LoginModel extends Equatable { ... }
class LoginCubit extends Cubit<LoginState> { ... }

// state.dart (part of cubit.dart)
sealed class LoginState extends Equatable { ... }
```

### 5. States: solo los del dominio propio

```dart
// ✅ estados propios del módulo
final class LoginIdleState extends LoginState { ... }
final class LoginLoadingState extends LoginState { ... }
final class LoginSuccessState extends LoginState { ... }
final class LoginErrorState extends LoginState { ... }

// ❌ nunca estados de flujos ajenos en el cubit padre
```

### 6. Navegación con valor de retorno

```dart
// navigator.dart del módulo
static Future<Song?> goToAdd() {
  return CustomNavigator.goTo<Song?>('/songs/add');
}

// en el llamador
final song = await SongsNavigator.goToAdd();
if (song != null) cubit.onSongCreated(song);
```

### 7. Cubit: un método de integración, no setters del flujo hijo

```dart
// ✅
void onSongAdded(Song song) { ... }

// ❌
void setSongTitle(String v) { ... }
void setSongAuthor(String v) { ... }
Future<void> addSong() async { ... }
```

### 8. Validar antes de navegar

```dart
Future<void> _onAddSong(BuildContext context) async {
  final cubit = context.read<SongsListCubit>();
  if (!cubit.canAddMore) {
    cubit.notifyLimit();
    return;
  }
  final song = await SongsNavigator.goToAdd();
  if (song != null) cubit.onSongAdded(song);
}
```

### 9. Registro en AppModule

Todo módulo nuevo va en `lib/module.dart`:

```dart
r.module('/songs', module: SongsModule(), guards: [AuthGuard()]);
r.module('/collections', module: CollectionsModule(), guards: [AuthGuard()]);
```

### 10. CoreModule en imports

Si el módulo usa `SupabaseService` o `ApiService`:

```dart
@override
List<Module> get imports => [CoreModule()];
```

---

## Módulos registrados

| Ruta | Módulo | Guard |
|------|--------|-------|
| `/auth` | `AuthModule` | — |
| `/songs` | `SongsModule` | `AuthGuard` |
| `/collections` | `CollectionsModule` | `AuthGuard` |
| `/templates` | `TemplatesModule` | `AuthGuard` |
| `/presentation` | `PresentationModule` | `AuthGuard` |

---

## Servicios core (inyectados vía CoreModule)

| Servicio | Descripción |
|----------|-------------|
| `SupabaseService` | Cliente Supabase (auth, realtime, DB) |
| `ApiService` | Cliente Dio → Go backend |

---

## Nota sobre segunda pantalla

En desktop (macOS/Windows), el módulo `presentation` manejará detección de monitores conectados
y apertura de ventana Display en la segunda pantalla (proyector/video beam).
API: `dart:ui` + platform channels para info de displays.
