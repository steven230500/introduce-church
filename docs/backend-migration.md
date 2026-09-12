# Migración: de Supabase a la API propia

Hecho en septiembre 2026. La app ya no depende de ningún servicio alojado por
terceros: identidad, datos y sincronización en vivo corren en tu droplet.

---

## Qué reemplazó a qué

| Antes (Supabase) | Ahora |
|---|---|
| Auth con `supabase_flutter` | Tabla `users` + argon2id + JWT propios |
| Postgres de Supabase | Postgres en contenedor, en tu droplet |
| Políticas RLS | Middleware de organización en Go |
| Realtime sobre `presentation_state` | Hub WebSocket en Go |
| Storage de Supabase | Disco del droplet, ya migrado antes |

La app dejó de tener la dependencia `supabase_flutter`. Toda la comunicación
pasa por una sola URL, `API_URL`.

---

## Cómo funciona la sesión

El servidor emite dos cosas al entrar:

- **Access token**: JWT HS256, vida de 15 minutos. Viaja en cada request.
- **Refresh token**: opaco, de un solo uso. El servidor guarda solo su hash
  sha256 y lo revoca al canjearlo.

`ApiClient` renueva el access token *antes* de que venza, no después de un 401,
para no gastar un viaje extra a mitad de un culto. Si dos requests necesitan
renovar a la vez comparten la misma operación: los refresh tokens son de un solo
uso y dos renovaciones en paralelo se pisarían.

**Detalle que importa:** al crear o unirse a una organización hay que renovar la
sesión. El token vigente se emitió antes de que existiera la membresía y no
lleva la organización dentro, así que sin renovar todo endpoint con alcance de
organización seguiría rechazando.

---

## El hub en vivo

El control publica su posición por WebSocket. El servidor la guarda y la
reenvía a las demás ventanas del mismo operador.

- Las salas se indexan por operador, así el proyector de una iglesia nunca
  recibe el culto de otra.
- Al conectar, el servidor manda el estado actual, para que una ventana abierta
  a mitad de canción muestre el slide correcto en vez de quedar en negro.
- Una ventana que deja de leer se descarta en vez de esperarla. Un cliente
  trabado nunca debe demorar el proyector.
- Si el socket está caído, el control escribe por HTTP. Más lento, pero el
  servicio sigue.

Las ventanas de proyección y escenario corren en su propio engine, así que cada
una lee la sesión guardada y abre su propia conexión.

---

## Poner la API en el droplet

```bash
# En el droplet, dentro del repo introduce-api
cp .env.example .env
```

Completá en `.env`:

```
POSTGRES_PASSWORD=<algo largo y aleatorio>
JWT_SECRET=<openssl rand -base64 48>
FILES_BASE_URL=https://files.introduce.tu-dominio.com
```

`docker compose` se niega a arrancar si falta cualquiera de esos dos secretos,
a propósito: es preferible que no levante a que levante con algo adivinable.

```bash
docker compose up -d --build
```

El esquema se aplica solo al arrancar. El migrador corre cada archivo pendiente
de `internal/db/migrations` en su propia transacción y anota cuáles ya pasaron.

Postgres no publica puerto al host y vive en una red interna que solo comparte
con la API.

---

## Traer los datos viejos

El exportador es un `curl` por tabla contra la API de Supabase. Con los archivos
JSON en una carpeta:

```bash
# Primero registrá la cuenta y creá la organización desde la app.
DATABASE_URL=postgres://... go run ./cmd/import-supabase \
  -dir ./export -email operador@tuiglesia.com -org "Casa Vida"
```

Reescribe cada identificador para que todo quede bajo esa cuenta y esa
organización. Se puede correr dos veces sin duplicar nada.

---

## Respaldos

Esto ahora es tuyo. Supabase lo hacía por vos y ya no.

```bash
# Volcado diario, en el droplet
docker compose exec -T db pg_dump -U introduce introduce \
  > /opt/backups/introduce-$(date +%F).sql
```

El compose monta `./backups` dentro del contenedor. Copiá esa carpeta fuera del
droplet: un respaldo que vive en la misma máquina no es un respaldo.

---

## Lo que no cambió

El JSON de colecciones conserva la forma que la app ya parseaba: los ítems
llegan bajo `collection_items` y la canción bajo `songs`. Por eso los modelos
del escritorio y sus tests no tuvieron que cambiar cuando cambió el backend
entero, y los 116 tests siguieron pasando.
