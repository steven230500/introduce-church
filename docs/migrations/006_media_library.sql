-- Media library: shared org media items
create table if not exists media_items (
  id           uuid        primary key default gen_random_uuid(),
  org_id       uuid        references organizations(id) on delete cascade,
  user_id      uuid        references auth.users(id) on delete cascade not null,
  name         text        not null,
  url          text        not null,
  storage_path text        not null,
  media_type   text        not null check (media_type in ('image', 'video')),
  size_bytes   bigint,
  created_at   timestamptz default now()
);

alter table media_items enable row level security;

create policy "org members can manage media"
  on media_items for all
  using (
    user_id = auth.uid()
    or org_id = get_my_org_id()
  )
  with check (
    user_id = auth.uid()
  );

-- Storage bucket: create manually in Supabase dashboard
-- Name: org-media, Public: false (use signed URLs or service-role for reads)
-- Or set Public: true and use the public URL directly (simpler for desktop)
