-- Notes per collection item
alter table collection_items
  add column if not exists notes text;
