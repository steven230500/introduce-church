-- ============================================================
-- Migration: Organizations & multi-user sharing
-- Run this in Supabase SQL Editor
-- ============================================================

-- 1. Organizations table
create table if not exists organizations (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  created_at  timestamptz default now()
);

-- 2. Organization members (pending / active / rejected)
create table if not exists organization_members (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references organizations(id) on delete cascade,
  user_id     uuid not null references auth.users(id) on delete cascade,
  role        text not null default 'member',   -- 'admin' | 'member'
  status      text not null default 'pending',  -- 'pending' | 'active' | 'rejected'
  email       text,                              -- denorm for display
  joined_at   timestamptz default now(),
  unique(org_id, user_id)
);

-- 3. User profiles (for showing author name)
create table if not exists profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  email        text,
  display_name text,
  updated_at   timestamptz default now()
);

-- Auto-create profile on new user
create or replace function handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure handle_new_user();

-- Backfill profiles for existing users (safe to re-run)
insert into profiles (id, email)
select id, email from auth.users
on conflict (id) do nothing;

-- 4. Add org_id + created_by to existing tables
alter table collections
  add column if not exists org_id      uuid references organizations(id),
  add column if not exists created_by  uuid references auth.users(id);

alter table templates
  add column if not exists org_id      uuid references organizations(id),
  add column if not exists created_by  uuid references auth.users(id);

alter table songs
  add column if not exists org_id      uuid references organizations(id),
  add column if not exists created_by  uuid references auth.users(id);

-- 5. Helper: get current user's active org_id
create or replace function get_my_org_id()
returns uuid
language sql
security definer
stable
as $$
  select org_id from organization_members
  where user_id = auth.uid() and status = 'active'
  limit 1;
$$;

-- 6. Helper: create org + add creator as admin (bypasses RLS)
create or replace function create_organization(org_name text)
returns organizations
language plpgsql
security definer
as $$
declare
  new_org organizations;
  u_email text;
begin
  insert into organizations(name) values (org_name) returning * into new_org;
  select email into u_email from auth.users where id = auth.uid();
  insert into organization_members(org_id, user_id, role, status, email)
  values (new_org.id, auth.uid(), 'admin', 'active', u_email);
  return new_org;
end;
$$;

-- 7. Helper: approve a pending member (admin only)
create or replace function approve_member(member_id uuid)
returns void
language plpgsql
security definer
as $$
begin
  if not exists (
    select 1 from organization_members
    where user_id = auth.uid()
      and status = 'active'
      and role = 'admin'
      and org_id = (select org_id from organization_members where id = member_id)
  ) then
    raise exception 'Unauthorized';
  end if;
  update organization_members set status = 'active' where id = member_id;
end;
$$;

-- 8. Helper: reject a pending member (admin only)
create or replace function reject_member(member_id uuid)
returns void
language plpgsql
security definer
as $$
begin
  if not exists (
    select 1 from organization_members
    where user_id = auth.uid()
      and status = 'active'
      and role = 'admin'
      and org_id = (select org_id from organization_members where id = member_id)
  ) then
    raise exception 'Unauthorized';
  end if;
  update organization_members set status = 'rejected' where id = member_id;
end;
$$;

-- 9. RLS: organizations
alter table organizations enable row level security;

create policy "org members can view their org"
  on organizations for select
  using (id = get_my_org_id());

-- Anyone authenticated can see org names for search/join
create policy "authenticated can search orgs"
  on organizations for select
  using (auth.uid() is not null);

-- 10. RLS: organization_members
alter table organization_members enable row level security;

-- Any authenticated user can submit a join request
create policy "anyone can request to join"
  on organization_members for insert
  with check (user_id = auth.uid() and status = 'pending');

-- Members can view their own org's members list
create policy "org members can view members"
  on organization_members for select
  using (org_id = get_my_org_id() or user_id = auth.uid());

-- 11. RLS: profiles
alter table profiles enable row level security;

create policy "org members can view profiles"
  on profiles for select
  using (
    auth.uid() is not null
    and (
      id = auth.uid()
      or id in (
        select user_id from organization_members
        where org_id = get_my_org_id() and status = 'active'
      )
    )
  );

create policy "users can update own profile"
  on profiles for update
  using (id = auth.uid());

-- 12. Update RLS on collections (keep backward compat: user_id OR org_id)
-- Drop old policy if it exists, add new one
drop policy if exists "Users can manage their own collections" on collections;
drop policy if exists "users can manage own collections" on collections;

create policy "users and org members can manage collections"
  on collections for all
  using (user_id = auth.uid() or org_id = get_my_org_id())
  with check (user_id = auth.uid() or org_id = get_my_org_id());

-- 13. Update RLS on songs
drop policy if exists "Users can manage their own songs" on songs;
drop policy if exists "users can manage own songs" on songs;

create policy "users and org members can manage songs"
  on songs for all
  using (user_id = auth.uid() or org_id = get_my_org_id())
  with check (user_id = auth.uid() or org_id = get_my_org_id());

-- 14. Update RLS on templates
drop policy if exists "Users can manage their own templates" on templates;
drop policy if exists "users can manage own templates" on templates;

create policy "users and org members can manage templates"
  on templates for all
  using (user_id = auth.uid() or org_id = get_my_org_id())
  with check (user_id = auth.uid() or org_id = get_my_org_id());
