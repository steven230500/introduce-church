-- Auto-advance per collection item
alter table collection_items
  add column if not exists auto_advance_secs integer;
