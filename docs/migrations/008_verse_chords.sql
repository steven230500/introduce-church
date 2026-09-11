-- Chord charts per verse
alter table verses
  add column if not exists chords text;
