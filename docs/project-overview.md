# introduce_church — Project Overview

Software de presentación para iglesias. Alternativa propia a ProPresenter / EasyWorship.  
Funciona **offline** (modo local) y **online** (sync entre dispositivos vía Supabase Realtime).

---

## Objetivo

Herramienta para el equipo de audiovisual de la iglesia:
- Proyectar letras de canciones en pantalla grande (proyector / video beam)
- Gestionar set lists por servicio
- Diseñar slides con templates personalizados
- Buscar letras de canciones cristianas
- Importar/exportar canciones y colecciones
- Detectar segunda pantalla automáticamente (proyector)

---

## Stack

| Capa | Tecnología | Razón |
|------|-----------|-------|
| App | Flutter 3.x | Desktop + Web + Tablet, un solo codebase |
| Estado | flutter_bloc (Cubit) | Predecible, testeable, patrón del proyecto |
| Módulos / DI | flutter_modular | Inyección de dependencias + routing |
| Base de datos | Supabase (PostgreSQL) | Managed, Realtime, Storage, Auth incluidos |
| Backend | Go + Gin *(pendiente)* | Import/Export, IA proxy, búsqueda externa |
| Auth | Supabase Auth | Un usuario por iglesia, RLS por `user_id` |
| Storage medios | Supabase Storage | Fondos, imágenes de templates |
| IA | Claude API *(pendiente)* | Generación de diseños de templates |
| Formatos | OpenLyrics XML *(pendiente)* | Estándar industria para canciones |
| HTTP client | Dio + PrettyDioLogger | Solo para Go backend, logs en dev |
| Logging | logger (appLogger) | Logs de Supabase + errores en consola |
| Env vars | flutter_dotenv | `.env` local, no hardcoded |

### Targets Flutter
- **Desktop macOS / Windows** — uso principal en la iglesia
- **Web** — panel de control desde navegador
- **Tablet (iPad / Android)** — control remoto durante el servicio

---

## Modelo de usuarios

**Un usuario = una iglesia.** Sin organizaciones ni multi-tenant.  
Cada iglesia crea su cuenta en Supabase Auth. RLS filtra todo por `user_id = auth.uid()`.  
Múltiples dispositivos de la misma iglesia comparten sesión vía Supabase Realtime.

---

## Arquitectura

```
┌─────────────────────────────────────────────────────┐
│                  Flutter Apps                       │
│  Desktop (Win/Mac)   Web (browser)   Tablet (iPad)  │
│                                                     │
│  ┌─────────────────┐                                │
│  │  Control Window  │  ← Panel del operador AV      │
│  ├─────────────────┤                                │
│  │  Display Window  │  ← Va al proyector (pantalla 2)│
│  └─────────────────┘                                │
└──────────────────┬──────────────────────────────────┘
                   │
          ┌────────▼────────┐
          │    Supabase      │
          │  Auth · Realtime │  ← presentation_state en vivo
          │  Storage · PG    │
          └────────┬─────────┘
                   │ (cuando hay internet)
          ┌────────▼────────┐
          │   Go Backend     │  ← Import/Export, IA, búsqueda externa
          │   Gin + sqlc     │
          └─────────────────┘
```

**Presentación en vivo:** Supabase Realtime sincroniza `presentation_state`. Control avanza slide → Display actualiza <100ms sin pasar por Go.

---

## Base de Datos (Supabase)

```
songs              — canciones (título, autor, copyright, CCLI, idioma, tags)
verses             — slides de cada canción (tipo: verso/coro/puente/pre-coro/tag/intro/outro)
templates          — diseños de slide (fondo, fuente, posición, sombra)
collections        — set lists por servicio (con fecha)
collection_items   — canciones dentro de un set list, en orden, con template asignado
presentation_state — estado en vivo por usuario (slide actual, is_live, blank_screen)
lyrics_cache       — caché de búsquedas de letras online
```

Todo indexado por `user_id`. RLS activo en todas las tablas.  
`presentation_state` habilitada en Supabase Realtime.

---

## Flutter — Estructura real `lib/`

```
lib/
├── main.dart                   # init: dotenv → Supabase → ModularApp
├── app.dart                    # MaterialApp.router
├── module.dart                 # AppModule: rutas + AuthGuard
├── core/
│   ├── config/
│   │   └── env.dart            # AppEnv (dev/prod via --dart-define)
│   ├── models/
│   │   ├── song.dart           # Song, Verse, VerseType
│   │   └── collection.dart     # Collection, CollectionItem
│   ├── module.dart             # CoreModule: SupabaseService + Dio
│   ├── services/
│   │   └── supabase_service.dart
│   └── utils/
│       ├── app_logger.dart     # appLogger global (PrettyPrinter)
│       └── navigator.dart      # CustomNavigator base
└── modules/
    ├── auth/
    │   ├── module.dart
    │   ├── utils/navigator.dart
    │   └── children/login/     # Login: email + password → Supabase Auth
    ├── presentation/           # ← PANTALLA PRINCIPAL
    │   ├── module.dart
    │   ├── utils/navigator.dart
    │   └── children/control/   # Panel operador: 3 columnas
    │       ├── presenter/
    │       │   ├── page.dart   # KeyboardListener (←→ Space B)
    │       │   ├── widgets/
    │       │   │   ├── body.dart
    │       │   │   ├── toolbar.dart        # En vivo + Pantalla negra
    │       │   │   ├── set_list_panel.dart # Selector colección + items
    │       │   │   ├── slide_preview.dart  # Preview 16:9 + controles
    │       │   │   └── slide_queue.dart    # Cola de slides de la canción
    │       │   └── cubit/
    │       └── repository/
    ├── songs/                  # CRUD canciones (en progreso)
    ├── collections/            # CRUD set lists (pendiente)
    └── templates/              # Editor templates (pendiente)
```

---

## Pantalla principal — Control

Layout de 3 paneles (estilo ProPresenter):

```
┌──────────────┬───────────────────────────┬──────────────┐
│  Set List    │     Preview 16:9           │  Slides      │
│              │  ┌─────────────────────┐   │              │
│  Colección   │  │                     │   │  [Coro]      │
│  selector    │  │   Letra del slide   │   │  [Verso 1] ← │
│              │  │                     │   │  [Puente]    │
│  1. Canción  │  └─────────────────────┘   │  [Coro]      │
│  2. Canción← │  ← Prev    Siguiente →     │              │
│  3. Canción  │  1 / 4                     │              │
└──────────────┴───────────────────────────┴──────────────┘
```

**Shortcuts de teclado:** `←` `→` `Space` navegar slides · `B` pantalla negra

---

## Funcionalidades

### Hecho ✅
- Auth (login con Supabase Auth)
- AuthGuard en rutas protegidas
- Schema Supabase completo con RLS
- Modelos: Song, Verse, Collection, CollectionItem
- Panel de control: 3 columnas, preview 16:9, controles, teclado
- Toolbar: toggle En vivo + Pantalla negra
- Sync de `presentation_state` a Supabase en cada acción
- Logging: `appLogger` en repos + `PrettyDioLogger` para Go backend
- Env vars via `.env` (no hardcoded)

### En progreso 🔧
- CRUD canciones + versos (módulo songs)

### Pendiente 📋
- CRUD colecciones / set lists
- Display Window (segunda ventana → proyector)
- Supabase Realtime en Display (sync con Control)
- Detección automática de segunda pantalla
- Templates: editor visual + fondos
- Import / Export OpenLyrics XML
- Búsqueda letras online + caché
- Go backend (import/export, IA proxy)
- Generación de templates con Claude API
- Import / Export colecciones (ZIP)
- Soporte offline (sqflite + sync)

---

## Formatos de Import/Export *(pendiente)*

| Formato | Descripción |
|---------|-------------|
| OpenLyrics XML | Estándar industria (compatible OpenLP, WorshipTools) |
| `.zip` colección | Set list completo: canciones + templates + orden |
| JSON | Templates internos |

---

## Flujo de uso típico

```
Sábado — preparación:
  1. Crear colección "Domingo 8 Jun"
  2. Buscar y agregar canciones en orden
  3. Asignar template a cada canción
  4. Ajustar letras si hace falta

Domingo — servicio en vivo:
  1. Abrir colección del día
  2. Conectar proyector → Display Window abre en pantalla 2 automático
  3. Tablet / web como control remoto secundario
  4. ← → o Space para navegar slides
  5. B para pantalla negra entre canciones
  6. Toggle "En vivo" para activar proyección
```

---

## Consideraciones

- **Un usuario por iglesia** — sin organizaciones. Cualquier equipo puede instalarlo con su cuenta.
- **CCLI** — campo `ccli_number` en canciones para cumplir licencias.
- **Idioma** — campo `language` en canciones, UI en español por defecto.
- **macOS sandbox** — `network.client` entitlement requerido en Debug + Release.
- **Conflicto context.read** — en pages que usan `Modular.to` + `context.read`: `import flutter_modular show Modular`.
