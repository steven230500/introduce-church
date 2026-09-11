# Arquitectura de UI

Cómo está organizada la interfaz y por qué. Escrito después de la reorganización
de septiembre 2026, que partió de un problema concreto: la gente se perdía.

---

## El problema que se resolvió

La app tenía dos mitades que no se hablaban.

1. **La barra de EN VIVO vivía dentro del presentador.** Entrar a Biblia o a
   Canciones la hacía desaparecer junto con pantalla negra, proyección y monitor.
   Estando en vivo, el operador se quedaba sin controles.
2. **Cada biblioteca existía dos veces**: como página del sidebar y como diálogo
   modal, con UI distinta. Ocho interfaces para cuatro cosas.
3. **Crear colección estaba en cuatro lugares con dos diálogos distintos.** Uno
   pedía fecha de servicio, el otro no.
4. **Todo escondido en menús kebab** de 13 a 18 píxeles.
5. **Spinner de pantalla completa en cada cambio.** Quince llamadas a `load()`
   emitían un estado de carga, así que agregar una canción borraba el set list.
6. **El toggle de cuadrícula reordenaba la ventana entera** desde un chip de 11px.
7. **Cero sistema de diseño.** 485 literales `Color(0xFF…)` repartidos por el código.
8. **Cero tests.**

---

## El modelo: presentador-céntrico

El presentador es la app. Todo lo demás orbita a su alrededor.

```
┌──────────────────────────────────────────────────────────────────┐
│ LiveBar    colección • elemento • 3/12   [⏱ 💬 ⬛] [📺 🖥] [●EN VIVO] │  ← siempre visible
├──────┬──────────────┬────────────────────────┬────────────────────┤
│ Side │  Set list    │  Preview / cuadrícula  │  LibraryDock       │
│ bar  │              │                        │  Canciones│Biblia  │
│  ▶   │  1 Canción   │                        │  Media    │Diseños │
│  📁  │  2 Salmo     │                        │                    │
│      │  3 Video     │                        │  buscar...         │
│  ⌨   │  + Agregar   │                        │  • Sublime Gracia +│
│  👥  │              │                        │  • Cuan Grande Es +│
└──────┴──────────────┴────────────────────────┴────────────────────┘
  64px      260px            elástico                  300px
```

**Reglas que sostienen el modelo:**

- La barra de EN VIVO vive en el shell, nunca en una sección. Un operador tiene
  que poder cortar la señal desde cualquier pantalla.
- Los atajos de teclado también viven en el shell, y se desactivan solos cuando
  el foco está en un campo de texto.
- Las bibliotecas no son destinos. Son un panel acoplado al presentador, para
  que agregar contenido nunca cueste perder de vista el proyector.
- El sidebar tiene dos destinos, no seis. Presentador para correr un servicio,
  Colecciones para planificarlo.

---

## Dónde vive cada cosa

| Archivo | Responsabilidad |
|---|---|
| `shell/shell_page.dart` | Marco: barra, sidebar, cuerpo, dock, atajos |
| `shell/shell_cubit.dart` | Sección activa, pestaña del dock, dock abierto |
| `shell/widgets/live_bar.dart` | Controles de proyección, siempre visibles |
| `shell/widgets/shortcuts_dialog.dart` | Referencia de teclado |
| `shell/widgets/collection_dialog.dart` | **El único** diálogo de colección |
| `shell/library/library_dock.dart` | Pestañas, indicador de destino, primitivas |
| `shell/library/*_panel.dart` | Un panel por biblioteca |
| `shell/collections_library_page.dart` | Rejilla de servicios planificados |
| `children/control/presenter/page.dart` | Presentador, sin Scaffold ni barra |
| `.../widgets/set_list/` | Set list, dividido por propósito |

El set list era un archivo de 1557 líneas con 20 clases y 10 diálogos. Ahora son
cinco partes: `panel`, `add_menu`, `importers`, `items`, `export`.

---

## Sistema de diseño

`core/theme/` es la única fuente de verdad.

- `app_colors.dart` — superficies ordenadas de la más oscura a la más clara,
  texto de primario a deshabilitado, acentos por rol.
- `app_dimens.dart` — escala de espaciado, radios, anchos de columna, tiempos.
- `app_text.dart` — cinco roles tipográficos, cada uno con un trabajo.

`core/widgets/ui/` tiene las primitivas compartidas: `PageHeader`, `PanelHeader`,
`EmptyState`, `ErrorStateView`, `AppSearchField`, `AppIconButton`, `AppMenuRow`.

**Nunca escribas `Color(0xFF…)` en un widget.** Agregá un token. Los tests de
`test/theme/tokens_test.dart` verifican que la rampa de superficies suba, que la
jerarquía de texto baje y que el contraste cumpla WCAG AA.

---

## Reglas de estado

`ControlCubit` tiene dos formas de recargar:

- `load()` emite estado de carga. Solo para el arranque y para recuperarse de un error.
- `refresh()` recarga sin emitir carga, y preserva el cursor, EN VIVO, pantalla
  negra, cuenta regresiva y overlay.

**Toda mutación usa `refresh()`.** Emitir un estado de carga después de una edición
deja el set list en blanco a mitad de servicio y se lee como un crash.

---

## Atajos de teclado

| Tecla | Acción |
|---|---|
| `→` `↓` `Espacio` | Siguiente slide |
| `←` `↑` | Slide anterior |
| `L` | Entrar o salir de vivo |
| `B` | Pantalla negra |
| `G` | Alternar cuadrícula y slide grande |
| `F` | Mostrar u ocultar la biblioteca |
| `Shift + /` | Abrir la ayuda de atajos |

---

## Tests

`make check` corre análisis estático más la suite completa. Nada toca la red ni
un proyector.

| Archivo | Qué cubre |
|---|---|
| `models/collection_item_test.dart` | Parseo de `content_json`, slides y etiquetas por tipo |
| `cubit/control_model_test.dart` | Navegación, clamping, resolución de diseño |
| `cubit/control_cubit_test.dart` | Carga, refresh sin spinner, mutaciones, estado de proyección |
| `cubit/shell_cubit_test.dart` | Navegación del shell y del dock |
| `theme/tokens_test.dart` | Rampas de color, contraste, escalas |
| `widget/ui_primitives_test.dart` | Componentes compartidos, debounce de búsqueda |
| `widget/live_bar_test.dart` | Controles globales, lectura de contexto |
| `widget/library_dock_test.dart` | Agregar al set list y su estado deshabilitado |
| `widget/presenter_test.dart` | Set list, modos de vista, menú de agregar |

Los fakes viven en `test/helpers/`. `FakeControlRepository` muta sus filas al
escribir, como lo haría un backend real: si no, una recarga emite un estado igual
al anterior, bloc lo suprime, y el test no distingue un refresh que funciona de
uno roto.
