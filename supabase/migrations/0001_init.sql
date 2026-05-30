-- RideTalk — initial schema
-- Run order: this file first, then 0002_rls.sql, then 0003_functions.sql
--
-- Conventions:
--   * UUID primary keys
--   * timestamps in UTC (timestamptz)
--   * profiles row is 1:1 with auth.users and created on signup via trigger

-- ─────────────────────────────────────────────────────────────────────────────
-- Extensions
-- ─────────────────────────────────────────────────────────────────────────────
create extension if not exists "pgcrypto";  -- gen_random_uuid()

-- ─────────────────────────────────────────────────────────────────────────────
-- profiles  (1:1 with auth.users)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  display_name  text not null default 'Rider',
  avatar_url    text,
  scooter_type  text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

comment on table public.profiles is 'Rider profile, 1:1 with auth.users';

-- ─────────────────────────────────────────────────────────────────────────────
-- rooms
-- ─────────────────────────────────────────────────────────────────────────────
create type public.room_status as enum ('active', 'ended');

create table if not exists public.rooms (
  id          uuid primary key default gen_random_uuid(),
  code        text not null unique,                 -- 6-char human join code
  name        text not null default 'Group Ride',
  host_id     uuid not null references public.profiles(id) on delete cascade,
  status      public.room_status not null default 'active',
  created_at  timestamptz not null default now(),
  ended_at    timestamptz
);

create index if not exists rooms_host_idx   on public.rooms(host_id);
create index if not exists rooms_status_idx on public.rooms(status);

comment on table public.rooms is 'A group ride room. `code` is the shareable join code.';

-- ─────────────────────────────────────────────────────────────────────────────
-- room_members  (room ↔ rider, with role + mute)
-- ─────────────────────────────────────────────────────────────────────────────
create type public.member_role as enum ('host', 'rider');

create table if not exists public.room_members (
  room_id    uuid not null references public.rooms(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  role       public.member_role not null default 'rider',
  is_muted   boolean not null default false,       -- host-enforced mute flag
  joined_at  timestamptz not null default now(),
  left_at    timestamptz,
  primary key (room_id, user_id)
);

create index if not exists room_members_user_idx on public.room_members(user_id);

comment on table public.room_members is 'Membership of riders in rooms, with role and mute state.';

-- ─────────────────────────────────────────────────────────────────────────────
-- music_states  (last shared track per room — compliant Sync Mode)
-- ─────────────────────────────────────────────────────────────────────────────
create type public.music_provider as enum ('spotify', 'appleMusic', 'other');

create table if not exists public.music_states (
  room_id      uuid primary key references public.rooms(id) on delete cascade,
  track_url    text not null,
  provider     public.music_provider not null default 'other',
  title        text,
  is_playing   boolean not null default false,
  position_ms  integer not null default 0,
  updated_by   uuid references public.profiles(id) on delete set null,
  updated_at   timestamptz not null default now()
);

comment on table public.music_states is 'Compliant Sync Mode: shared track link + play/pause/position. No audio is stored or rebroadcast.';

-- ─────────────────────────────────────────────────────────────────────────────
-- ride_locations  (optional persisted pings, for late-joiners / history)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.ride_locations (
  id          bigint generated always as identity primary key,
  room_id     uuid not null references public.rooms(id) on delete cascade,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  lat         double precision not null,
  lng         double precision not null,
  speed_mps   double precision,            -- meters/second, nullable
  heading     double precision,            -- degrees, nullable
  battery     real,                        -- 0..1, nullable
  recorded_at timestamptz not null default now()
);

create index if not exists ride_locations_room_time_idx
  on public.ride_locations(room_id, recorded_at desc);

comment on table public.ride_locations is 'Throttled location pings, room-scoped, for history and late joiners.';

-- ─────────────────────────────────────────────────────────────────────────────
-- updated_at trigger helper
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- ─────────────────────────────────────────────────────────────────────────────
-- Auto-create a profile row when a new auth user signs up
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', 'Rider')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ─────────────────────────────────────────────────────────────────────────────
-- Enable Realtime on the tables the app subscribes to
-- ─────────────────────────────────────────────────────────────────────────────
alter publication supabase_realtime add table public.room_members;
alter publication supabase_realtime add table public.music_states;
alter publication supabase_realtime add table public.ride_locations;
