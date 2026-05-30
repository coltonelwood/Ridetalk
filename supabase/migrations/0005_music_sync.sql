-- RideTalk — music sync host-controlled state
-- Apply after 0004_crash_detection.sql
--
-- shared_music_links already carries is_playing / position_ms (placeholders from 0001).
-- Music sync turns these into host-controlled shared state. We add `updated_at` as the
-- timestamp anchor so followers can PROJECT the current position:
--     projected = position_ms + (now - updated_at)   (while is_playing)
--
-- No audio is ever stored or rebroadcast — only the link + play/pause/position. See
-- docs/MUSIC_COMPLIANCE.md and docs/MUSIC_SYNC.md.

alter table public.shared_music_links
  add column if not exists updated_at timestamptz not null default now();

comment on column public.shared_music_links.updated_at is
  'Timestamp anchor for position_ms so riders can project the current playback position.';
