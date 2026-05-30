-- RideTalk — initial schema (full MVP spec)
-- Run order: 0001_init.sql → 0002_rls.sql → 0003_functions.sql
--
-- Tables: users, rider_profiles, ride_rooms, room_members, live_locations,
--         sos_alerts, ride_recordings, ride_stats, shared_music_links, quick_messages

create extension if not exists "pgcrypto";  -- gen_random_uuid()

-- ─────────────────────────────────────────────────────────────────────────────
-- users  (mirror of auth.users so app tables can FK a public table)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.users (
  id          uuid primary key references auth.users(id) on delete cascade,
  email       text,
  created_at  timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- rider_profiles  (1:1 with users)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.rider_profiles (
  user_id            uuid primary key references public.users(id) on delete cascade,
  display_name       text not null default 'Rider',
  photo_url          text,
  vehicle_type       text,        -- scooter | e-bike | motorcycle | UTV | other
  vehicle_name       text,        -- e.g. "Apollo City Pro"
  emergency_contact  text,        -- PLACEHOLDER: future SOS contact (name/phone)
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- ride_rooms
-- ─────────────────────────────────────────────────────────────────────────────
create type public.room_status as enum ('active', 'ended');

create table if not exists public.ride_rooms (
  id                          uuid primary key default gen_random_uuid(),
  code                        text not null unique,            -- 6-char join code
  name                        text not null default 'Group Ride',
  host_id                     uuid not null references public.users(id) on delete cascade,
  lead_rider_id               uuid references public.users(id) on delete set null,
  status                      public.room_status not null default 'active',
  separation_threshold_miles  numeric(4,2) not null default 1.0,  -- host-set alert distance
  created_at                  timestamptz not null default now(),
  ended_at                    timestamptz
);

create index if not exists ride_rooms_host_idx   on public.ride_rooms(host_id);
create index if not exists ride_rooms_status_idx on public.ride_rooms(status);

-- ─────────────────────────────────────────────────────────────────────────────
-- room_members  (room ↔ rider)
-- ─────────────────────────────────────────────────────────────────────────────
create type public.member_role as enum ('host', 'rider');
create type public.subgroup    as enum ('front', 'middle', 'rear', 'none'); -- PLACEHOLDER feature

create table if not exists public.room_members (
  room_id    uuid not null references public.ride_rooms(id) on delete cascade,
  user_id    uuid not null references public.users(id) on delete cascade,
  role       public.member_role not null default 'rider',
  is_muted   boolean not null default false,    -- host-enforced mute
  subgroup   public.subgroup not null default 'none',
  joined_at  timestamptz not null default now(),
  left_at    timestamptz,
  primary key (room_id, user_id)
);

create index if not exists room_members_user_idx on public.room_members(user_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- live_locations  (latest known location per rider in a room; upserted)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.live_locations (
  room_id       uuid not null references public.ride_rooms(id) on delete cascade,
  user_id       uuid not null references public.users(id) on delete cascade,
  lat           double precision not null,
  lng           double precision not null,
  speed_mps     double precision,
  heading       double precision,      -- degrees of travel direction
  battery       real,                  -- 0..1
  signal        text,                  -- good | weak | lost
  is_connected  boolean not null default true,
  updated_at    timestamptz not null default now(),
  primary key (room_id, user_id)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- sos_alerts
-- ─────────────────────────────────────────────────────────────────────────────
create type public.sos_status as enum ('active', 'resolved');

create table if not exists public.sos_alerts (
  id          uuid primary key default gen_random_uuid(),
  room_id     uuid not null references public.ride_rooms(id) on delete cascade,
  user_id     uuid not null references public.users(id) on delete cascade,
  lat         double precision,
  lng         double precision,
  message     text,
  status      public.sos_status not null default 'active',
  created_at  timestamptz not null default now(),
  resolved_at timestamptz
);

create index if not exists sos_alerts_room_idx on public.sos_alerts(room_id, created_at desc);

-- ─────────────────────────────────────────────────────────────────────────────
-- ride_recordings  (route is a jsonb array of points)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.ride_recordings (
  id          uuid primary key default gen_random_uuid(),
  room_id     uuid references public.ride_rooms(id) on delete set null,
  user_id     uuid not null references public.users(id) on delete cascade,
  title       text,
  started_at  timestamptz not null default now(),
  ended_at    timestamptz,
  route       jsonb not null default '[]'::jsonb,   -- [{lat,lng,t,speed}]
  created_at  timestamptz not null default now()
);

create index if not exists ride_recordings_user_idx on public.ride_recordings(user_id, started_at desc);

-- ─────────────────────────────────────────────────────────────────────────────
-- ride_stats  (1:1 summary for a recording)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.ride_stats (
  recording_id   uuid primary key references public.ride_recordings(id) on delete cascade,
  distance_m     double precision not null default 0,
  duration_s     double precision not null default 0,
  avg_speed_mps  double precision not null default 0,
  max_speed_mps  double precision not null default 0,
  started_at     timestamptz,
  ended_at       timestamptz
);

-- ─────────────────────────────────────────────────────────────────────────────
-- shared_music_links  (compliant: link only; sync fields are PLACEHOLDERS)
-- ─────────────────────────────────────────────────────────────────────────────
create type public.music_provider as enum ('spotify', 'appleMusic', 'youtubeMusic', 'other');

create table if not exists public.shared_music_links (
  id          uuid primary key default gen_random_uuid(),
  room_id     uuid not null references public.ride_rooms(id) on delete cascade,
  user_id     uuid references public.users(id) on delete set null,
  url         text not null,
  provider    public.music_provider not null default 'other',
  title       text,
  -- PLACEHOLDER fields for future music-sync controls (not used to rebroadcast audio):
  is_playing  boolean not null default false,
  position_ms integer not null default 0,
  created_at  timestamptz not null default now()
);

create index if not exists shared_music_links_room_idx on public.shared_music_links(room_id, created_at desc);

-- ─────────────────────────────────────────────────────────────────────────────
-- quick_messages  ("Stopping", "Need gas", "Slow down", "I'm behind", "All good")
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.quick_messages (
  id          uuid primary key default gen_random_uuid(),
  room_id     uuid not null references public.ride_rooms(id) on delete cascade,
  user_id     uuid not null references public.users(id) on delete cascade,
  kind        text not null,                       -- stopping | gas | slow_down | behind | all_good | custom
  text        text not null,
  is_priority boolean not null default false,      -- priority msgs interrupt normal flow
  created_at  timestamptz not null default now()
);

create index if not exists quick_messages_room_idx on public.quick_messages(room_id, created_at desc);

-- ─────────────────────────────────────────────────────────────────────────────
-- updated_at trigger
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;

create trigger rider_profiles_set_updated_at
  before update on public.rider_profiles
  for each row execute function public.set_updated_at();

-- ─────────────────────────────────────────────────────────────────────────────
-- On signup: create users + rider_profiles rows
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.users (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;

  insert into public.rider_profiles (user_id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', 'Rider'))
  on conflict (user_id) do nothing;

  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ─────────────────────────────────────────────────────────────────────────────
-- Realtime: broadcast changes the app subscribes to
-- ─────────────────────────────────────────────────────────────────────────────
alter publication supabase_realtime add table public.room_members;
alter publication supabase_realtime add table public.live_locations;
alter publication supabase_realtime add table public.shared_music_links;
alter publication supabase_realtime add table public.sos_alerts;
alter publication supabase_realtime add table public.quick_messages;
alter publication supabase_realtime add table public.ride_rooms;
