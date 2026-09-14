# Migración: de Supabase a la API propia

Hecha y desplegada el 11 de septiembre de 2026. La app ya no depende de ningún
servicio alojado por terceros: identidad, datos y sincronización en vivo corren
en tu droplet.

**En producción:** `https://api.introducechurch.com` (desde el 14 de septiembre;
`https://api.introduce.casavidactg.com` sigue respondiendo para las copias
instaladas antes y los archivos subidos con esa dirección)
**En el droplet:** `/opt/introduce` (compose con `introduce-api` + `introduce-db`)

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

## Cómo se despliega ahora

Cada push a `main` en `introduce-api` construye la imagen, la publica en GHCR,
la baja al droplet y espera a que `/health` responda. Si la imagen no arranca,
la corrida falla en vez de pasar en verde.

La llave que usa el CI está limitada en el droplet a ese único comando, así que
si el secreto se filtra no sirve como shell.

Para desplegar a mano:

```bash
ssh introduce-droplet
cd /opt/introduce && docker compose pull && docker compose up -d
```

El esquema se aplica solo al arrancar. El migrador corre cada archivo pendiente
de `internal/db/migrations` en su propia transacción y anota cuáles ya pasaron.

Postgres no publica puerto al host y vive en una red interna que solo comparte
con la API. Los secretos están en `/opt/introduce/.env`, con permisos 600.

Caddy apunta al contenedor por nombre, no por IP: antes tenía `172.22.0.8`
fijo, que queda apuntando a la nada en cuanto el contenedor se recrea.

---

## Los datos viejos

Ya migraron: 3 canciones, 35 versos, 5 diseños, 3 colecciones, 14 elementos y 3
archivos de media, todos bajo la cuenta `spatino.gu@gmail.com` y la organización
Casa Vida. Los archivos subidos siguen en el mismo volumen `introduce_uploads`,
así que las URL de media no cambiaron.

Si alguna vez hace falta repetirlo:

```bash
DATABASE_URL=postgres://... go run ./cmd/import-supabase \
  -dir ./export -email operador@tuiglesia.com -org "Casa Vida"
```

Reescribe cada identificador para que todo quede bajo esa cuenta y esa
organización. Se puede correr dos veces sin duplicar nada.

## Cambiar la contraseña

```bash
curl -X POST https://api.introducechurch.com/account/password \
  -H "Authorization: Bearer <tu access token>" \
  -H "Content-Type: application/json" \
  -d '{"current_password":"<la actual>","new_password":"<la nueva>"}'
```

Cambiarla cierra todas las sesiones, incluida la que hizo el cambio. Todavía no
hay pantalla para esto en la app.

---

## Respaldos

Ya están andando: `/opt/introduce/backup.sh` corre por cron todos los días a las
3:30 y deja un volcado comprimido en `/opt/introduce/backups`, conservando 14
días.

Escribe a un archivo temporal y recién ahí lo mueve, para no dejar un respaldo
truncado que parezca bueno.

Probar que un respaldo sirve de verdad, que es lo único que cuenta:

```bash
ssh introduce-droplet
set -a; . /opt/introduce/.env; set +a
docker exec introduce-db psql -U "$POSTGRES_USER" -d postgres -c "create database restore_test;"
gunzip -c /opt/introduce/backups/introduce-YYYY-MM-DD.sql.gz \
  | docker exec -i introduce-db psql -U "$POSTGRES_USER" -d restore_test
docker exec introduce-db psql -U "$POSTGRES_USER" -d restore_test -c "select count(*) from songs;"
docker exec introduce-db psql -U "$POSTGRES_USER" -d postgres -c "drop database restore_test;"
```

**Lo que falta:** esa carpeta vive en el mismo disco que la base. Un respaldo en
la misma máquina no es un respaldo. Falta copiarla afuera, a Spaces de
DigitalOcean o a donde prefieras.

---

## Lo que no cambió

El JSON de colecciones conserva la forma que la app ya parseaba: los ítems
llegan bajo `collection_items` y la canción bajo `songs`. Por eso los modelos
del escritorio y sus tests no tuvieron que cambiar cuando cambió el backend
entero, y los 116 tests siguieron pasando.
