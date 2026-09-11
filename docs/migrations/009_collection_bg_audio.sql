-- Background audio track per collection (local file path)
alter table collections
  add column if not exists bg_audio_path text;
