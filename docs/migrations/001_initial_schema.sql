-- ============================================================
-- introduce_church — Supabase Schema
-- Ejecutar en: Supabase Dashboard > SQL Editor > New query
-- ============================================================

-- Extensions
create extension if not exists "pg_trgm";

-- ============================================================
-- SONGS
-- ============================================================
create table songs (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid references auth.users(id) on delete cascade not null,
  title        text not null,
  author       text,
  copyright    text,
  ccli_number  text,
  language     text default 'es',
  tags         text[] default '{}',
  created_at   timestamptz default now(),
  updated_at   timestamptz default now()
);

create index songs_title_trgm_idx on songs using gin (title gin_trgm_ops);
create index songs_user_id_idx on songs(user_id);

create table verses (
  id           uuid primary key default gen_random_uuid(),
  song_id      uuid references songs(id) on delete cascade not null,
  type         text not null check (type in ('verse','chorus','bridge','pre-chorus','tag','intro','outro')),
  verse_order  integer not null,
  content      text not null
);

create index verses_song_id_idx on verses(song_id);

-- ============================================================
-- TEMPLATES
-- ============================================================
create table templates (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid references auth.users(id) on delete cascade not null,
  name              text not null,
  background_type   text not null default 'color' check (background_type in ('color','image','video','gradient')),
  background_value  text,
  font_family       text default 'Inter',
  font_size         integer default 48,
  font_color        text default '#FFFFFF',
  text_shadow       jsonb,
  text_position     jsonb default '{"x": 0, "y": 0, "width": 100, "height": 100, "align": "center"}',
  is_default        boolean default false,
  created_at        timestamptz default now()
);

create index templates_user_id_idx on templates(user_id);

-- ============================================================
-- COLLECTIONS (set lists)
-- ============================================================
create table collections (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid references auth.users(id) on delete cascade not null,
  name          text not null,
  service_date  date,
  notes         text,
  created_at    timestamptz default now()
);

create index collections_user_id_idx on collections(user_id);

create table collection_items (
  id               uuid primary key default gen_random_uuid(),
  collection_id    uuid references collections(id) on delete cascade not null,
  song_id          uuid references songs(id) on delete cascade not null,
  template_id      uuid references templates(id) on delete set null,
  item_order       integer not null,
  custom_overrides jsonb
);

create index collection_items_collection_id_idx on collection_items(collection_id);

-- ============================================================
-- PRESENTATION STATE (realtime)
-- ============================================================
create table presentation_state (
  id                   uuid primary key default gen_random_uuid(),
  user_id              uuid references auth.users(id) on delete cascade unique not null,
  collection_id        uuid references collections(id) on delete set null,
  current_item_index   integer default 0,
  current_slide_index  integer default 0,
  is_live              boolean default false,
  blank_screen         boolean default false,
  updated_at           timestamptz default now()
);

-- ============================================================
-- LYRICS CACHE
-- ============================================================
create table lyrics_cache (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid references auth.users(id) on delete cascade not null,
  search_query text not null,
  source       text,
  result_json  jsonb,
  cached_at    timestamptz default now(),
  unique (user_id, search_query)
);

-- ============================================================
-- AUTO-UPDATE updated_at
-- ============================================================
create or replace function update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger songs_updated_at
  before update on songs
  for each row execute function update_updated_at();

create trigger presentation_state_updated_at
  before update on presentation_state
  for each row execute function update_updated_at();

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
alter table songs              enable row level security;
alter table verses             enable row level security;
alter table templates          enable row level security;
alter table collections        enable row level security;
alter table collection_items   enable row level security;
alter table presentation_state enable row level security;
alter table lyrics_cache       enable row level security;

-- SONGS
create policy "users manage own songs"
  on songs for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- VERSES (acceso via song del usuario)
create policy "users manage own verses"
  on verses for all
  using (song_id in (select id from songs where user_id = auth.uid()))
  with check (song_id in (select id from songs where user_id = auth.uid()));

-- TEMPLATES
create policy "users manage own templates"
  on templates for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- COLLECTIONS
create policy "users manage own collections"
  on collections for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- COLLECTION ITEMS (acceso via collection del usuario)
create policy "users manage own collection items"
  on collection_items for all
  using (collection_id in (select id from collections where user_id = auth.uid()))
  with check (collection_id in (select id from collections where user_id = auth.uid()));

-- PRESENTATION STATE
create policy "users manage own presentation state"
  on presentation_state for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- LYRICS CACHE
create policy "users manage own lyrics cache"
  on lyrics_cache for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ============================================================
-- REALTIME
-- ============================================================
alter publication supabase_realtime add table presentation_state;
