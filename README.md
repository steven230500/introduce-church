# Introduce

Software de proyección para iglesias de habla hispana. Letras, versículos,
avisos y videos en la pantalla del templo, manejados desde una sola ventana por
la persona que está en la consola un domingo a las ocho de la mañana.

Es una alternativa a ProPresenter pensada para el caso real de la mayoría de
las iglesias: un portátil, un proyector, alguien que aprendió a usarlo hace dos
semanas y una conexión a internet que a veces no está.

![Panel principal](docs/screenshots/panel-principal.png)

---

## Qué hace

**Servicio completo en una lista.** Canciones, pasajes, videos, imágenes y
puntos de la predicación en un solo orden. Se arrastra, se renombra, se
duplica el domingo pasado para armar el siguiente.

**Preview y programa separados.** El cursor se mueve por la lista sin tocar lo
que la congregación está viendo. Se manda a pantalla cuando está listo. El
panel *A continuación* muestra lo que sigue para no navegar a ciegas.

**Biblia offline.** Reina-Valera 1960 completa dentro de la app, sin internet.
Búsqueda por libro o escribiendo la referencia directo: `jn 3:16`, `sal 23`.

![Biblia](docs/screenshots/biblia.png)

**Editor de diseños.** Fondo sólido, degradado o foto; tipografía, tamaño,
interlineado, márgenes, sombra, transición. Dos modos: uno simple con
controles, y uno de capas con lienzo, guías e imanes para colocar los bloques a
mano.

<p align="center">
  <img src="docs/screenshots/editor-diseno.png" width="49%" alt="Editor de diseño">
  <img src="docs/screenshots/editor-capas.png" width="49%" alt="Editor de capas">
</p>

- El tamaño del diseño es un techo, no un valor fijo: un salmo largo se achica
  hasta caber en vez de cortarse contra el borde de abajo.
- El editor avisa si el texto no se va a leer desde el fondo del salón, con la
  relación de contraste real. También sobre foto, midiendo la foto por debajo
  de la capa de oscuridad.
- Los colores de la foto se ofrecen como paleta, y la iglesia puede guardar los
  suyos para todos los diseños.
- Deshacer y rehacer con ⌘Z / ⇧⌘Z. Cerrar con cambios pregunta antes.

**Avisos en medio de la predicación.** Una línea sobre el slide que ve la
congregación, con reloj para que se quite sola, o un mensaje que solo ve el
equipo en la pantalla de escenario. Los avisos que se repiten cada domingo se
guardan y quedan a un clic.

![Avisos](docs/screenshots/avisos.png)

**Pantalla de escenario.** Ventana aparte para el predicador o el músico: lo
que está en pantalla, lo que sigue, y los mensajes del equipo.

**Modo sin internet.** El servicio arranca y funciona sin red. La sesión
sobrevive, los diseños quedan en caché y la app avisa cuando no alcanza el
servidor en vez de quedarse callada.

**Vista de slide grande.** Para cuando la cuadrícula estorba y lo único que
importa es lo que está saliendo ahora.

![Slide grande](docs/screenshots/slide-grande.png)

---

## Estado

| Plataforma | Estado |
|---|---|
| macOS | Funcionando, sin firmar todavía |
| Windows | Compila, falta probar en equipo real |
| Linux | Pendiente |
| Control desde el teléfono | Pendiente |

---

## Cómo correrlo

Requiere Flutter (canal stable, Dart 3.11 o superior).

```bash
make deps      # flutter pub get
make run       # abre la app en macOS
make check     # análisis estático + toda la suite de tests
```

Empaquetar para repartir:

```bash
make dist-mac       # dist/Introduce-AAAAMMDD.zip
make dist-windows   # correr esto en una máquina Windows
```

La primera vez en un Mac ajeno hay que abrirla con clic derecho → Abrir,
porque todavía no está firmada con certificado de Apple.

Borrar datos locales y empezar de cero:

```bash
make reset
```

---

## Cómo está armado

Flutter para escritorio, con `flutter_modular` para rutas e inyección y
`flutter_bloc` (Cubit) para el estado. El proyector y la pantalla de escenario
son ventanas aparte, en motores propios, con `desktop_multi_window`.

```
lib/
  core/
    api/            cliente HTTP e interceptores
    local_db/       drift/SQLite: Biblia y caché offline
    models/         colección, elemento, slide, diseño, capa
    repositories/   una por recurso del backend
    services/       preferencias, ventanas, sesión
    theme/          colores, medidas, tipografía
    widgets/        SlideView, editor de diseños, biblioteca de medios
    windows/        canal entre la ventana principal y las secundarias
  modules/
    auth/           entrar y registrarse
    collections/    servicios y su contenido
    presentation/   la consola del operador
    display/        lo que ve la congregación
    stage/          lo que ve el equipo
    songs/          canciones y letras
    templates/      diseños
```

Más detalle en [docs/architecture.md](docs/architecture.md) y
[docs/ui-architecture.md](docs/ui-architecture.md).

El backend es un servicio aparte en Go:
[introduce-api](https://github.com/steven230500/introduce-api).

---

## Tests

```bash
make test
```

La suite cubre los cubits, los modelos, la resolución de referencias bíblicas,
el ajuste de texto, el contraste, las guías del lienzo y el comportamiento de
los diálogos. Los tests describen la situación real que evitan, no el método
que llaman.
