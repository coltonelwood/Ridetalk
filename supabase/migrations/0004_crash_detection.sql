-- RideTalk — possible crash / rider-down detection
-- Apply after 0003_functions.sql
--
-- Adds a `kind` discriminator to sos_alerts so the UI can distinguish a manually-raised
-- SOS from an auto-detected "possible crash / rider down" alert. Kept as text (not an enum)
-- to keep this migration trivial and forward-compatible.

alter table public.sos_alerts
  add column if not exists alert_kind text not null default 'manual';
  -- values: 'manual' | 'possible_crash'

comment on column public.sos_alerts.alert_kind is
  'How the alert was raised: manual (button) or possible_crash (auto-detected, UNCONFIRMED).';
