-- ============================================================
-- Migration 004: Countdown + overlay fields on presentation_state
-- ============================================================

alter table presentation_state
  add column if not exists countdown_active  boolean    default false,
  add column if not exists countdown_end     timestamptz,
  add column if not exists overlay_visible   boolean    default false,
  add column if not exists overlay_text      text;
