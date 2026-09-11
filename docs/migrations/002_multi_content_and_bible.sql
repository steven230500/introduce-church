-- ============================================================
-- Migration 002: Multi-content items + Bible cache
-- Ejecutar en: Supabase Dashboard > SQL Editor > New query
-- ============================================================

-- ============================================================
-- 1. collection_items — soporte multi-tipo
--    song_id ya no es NOT NULL, se agrega item_type + content_json
-- ============================================================
alter table collection_items
  alter column song_id drop not null,
  add column if not exists item_type text not null default 'song'
    check (item_type in ('song', 'bible_verse', 'sermon', 'free_slide')),
  add column if not exists content_json jsonb;

-- Asegurar que song_id existe cuando item_type = 'song'
alter table collection_items
  add constraint item_type_song_requires_song_id
    check (item_type != 'song' or song_id is not null);

-- ============================================================
-- 2. bible_cache — caché por capítulo (para prefetch eficiente)
--    Una fila = un capítulo completo de una versión
-- ============================================================
create table if not exists bible_cache (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references auth.users(id) on delete cascade not null,
  version     text not null,    -- 'RVR1960' | 'NVI'
  book_id     text not null,    -- ID de api.bible ej: 'JHN', 'GEN'
  book_name   text not null,    -- nombre legible ej: 'Juan'
  chapter     integer not null,
  verses_json jsonb not null,   -- array [{verse: 1, text: "..."}, ...]
  cached_at   timestamptz default now(),
  unique (user_id, version, book_id, chapter)
);

create index bible_cache_lookup_idx
  on bible_cache(user_id, version, book_id, chapter);

-- ============================================================
-- 3. bible_books — catálogo de libros por versión (para UI)
--    Se precarga una vez con la lista de libros de api.bible
-- ============================================================
create table if not exists bible_books (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references auth.users(id) on delete cascade not null,
  version     text not null,
  book_id     text not null,    -- ID api.bible ej: 'JHN'
  book_name   text not null,    -- 'Juan'
  testament   text not null check (testament in ('OT', 'NT')),
  chapters    integer not null,
  cached_at   timestamptz default now(),
  unique (user_id, version, book_id)
);

-- ============================================================
-- 4. RLS para tablas nuevas
-- ============================================================
alter table bible_cache  enable row level security;
alter table bible_books  enable row level security;

create policy "users manage own bible cache"
  on bible_cache for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "users manage own bible books"
  on bible_books for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
