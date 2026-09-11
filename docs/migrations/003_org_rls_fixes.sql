-- ============================================================
-- Migration 003: Fix RLS for org members + item_type constraint
-- ============================================================

-- 1. Fix collection_items RLS (was only user_id, not org members)
drop policy if exists "users manage own collection items" on collection_items;
create policy "users and org members can manage collection items"
  on collection_items for all
  using (
    collection_id in (
      select id from collections
      where user_id = auth.uid() or org_id = get_my_org_id()
    )
  )
  with check (
    collection_id in (
      select id from collections
      where user_id = auth.uid() or org_id = get_my_org_id()
    )
  );

-- 2. Fix verses RLS (org member B couldn't see verses of songs created by member A)
drop policy if exists "users manage own verses" on verses;
create policy "users and org members can manage verses"
  on verses for all
  using (
    song_id in (
      select id from songs
      where user_id = auth.uid() or org_id = get_my_org_id()
    )
  )
  with check (
    song_id in (
      select id from songs
      where user_id = auth.uid() or org_id = get_my_org_id()
    )
  );

-- 3. Expand item_type check constraint to include image_slide and video_slide
alter table collection_items
  drop constraint if exists collection_items_item_type_check;
alter table collection_items
  add constraint collection_items_item_type_check
  check (item_type in ('song','bible_verse','sermon','free_slide','image_slide','video_slide'));

-- ============================================================
-- NOTE: Columns added manually (not in prior migration files)
-- ============================================================
-- collections.template_id text  (added to allow per-collection template)
-- collections.org_id uuid       (added in migration_organizations.sql)
-- collections.created_by uuid   (added in migration_organizations.sql)
-- templates.config jsonb        (replaces individual background_*/font_* columns)
-- collection_items.template_id  (originally uuid, changed to text to support preset IDs)
