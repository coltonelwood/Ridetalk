-- RideTalk — Row Level Security
-- Apply after 0001_init.sql
--
-- Principle: a rider can only read/write data for rooms they belong to. Host-only fields
-- (mute/remove others, lead rider, threshold, end room) are gated by is_room_host().

-- ─────────────────────────────────────────────────────────────────────────────
-- Membership / host helpers
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.is_room_member(p_room_id uuid)
returns boolean language sql security definer set search_path = public stable as $$
  select exists (
    select 1 from public.room_members m
    where m.room_id = p_room_id and m.user_id = auth.uid() and m.left_at is null
  );
$$;

create or replace function public.is_room_host(p_room_id uuid)
returns boolean language sql security definer set search_path = public stable as $$
  select exists (
    select 1 from public.ride_rooms r
    where r.id = p_room_id and r.host_id = auth.uid()
  );
$$;

-- ───────────────────────── users ─────────────────────────
alter table public.users enable row level security;

create policy "read own user row" on public.users
  for select to authenticated using (id = auth.uid());

-- ───────────────────────── rider_profiles ─────────────────────────
alter table public.rider_profiles enable row level security;

-- Any authenticated user can read profiles (needed to render rosters/avatars).
create policy "profiles readable" on public.rider_profiles
  for select to authenticated using (true);

create policy "manage own profile (insert)" on public.rider_profiles
  for insert to authenticated with check (user_id = auth.uid());

create policy "manage own profile (update)" on public.rider_profiles
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ───────────────────────── ride_rooms ─────────────────────────
alter table public.ride_rooms enable row level security;

-- Read if you're a member/host, or it's an active room you're looking up to join by code.
create policy "read rooms" on public.ride_rooms
  for select to authenticated
  using (status = 'active' or host_id = auth.uid() or public.is_room_member(id));

create policy "create own room" on public.ride_rooms
  for insert to authenticated with check (host_id = auth.uid());

create policy "host updates room" on public.ride_rooms
  for update to authenticated using (host_id = auth.uid()) with check (host_id = auth.uid());

-- ───────────────────────── room_members ─────────────────────────
alter table public.room_members enable row level security;

create policy "members read roster" on public.room_members
  for select to authenticated
  using (public.is_room_member(room_id) or public.is_room_host(room_id));

create policy "join self" on public.room_members
  for insert to authenticated with check (user_id = auth.uid());

create policy "update own membership" on public.room_members
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "host moderates members" on public.room_members
  for update to authenticated using (public.is_room_host(room_id)) with check (public.is_room_host(room_id));

create policy "host removes members" on public.room_members
  for delete to authenticated using (public.is_room_host(room_id));

-- ───────────────────────── live_locations ─────────────────────────
alter table public.live_locations enable row level security;

create policy "members read locations" on public.live_locations
  for select to authenticated using (public.is_room_member(room_id));

create policy "insert own location" on public.live_locations
  for insert to authenticated with check (user_id = auth.uid() and public.is_room_member(room_id));

create policy "update own location" on public.live_locations
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ───────────────────────── sos_alerts ─────────────────────────
alter table public.sos_alerts enable row level security;

create policy "members read sos" on public.sos_alerts
  for select to authenticated using (public.is_room_member(room_id));

create policy "create own sos" on public.sos_alerts
  for insert to authenticated with check (user_id = auth.uid() and public.is_room_member(room_id));

-- Sender or host can resolve an alert.
create policy "resolve sos" on public.sos_alerts
  for update to authenticated
  using (user_id = auth.uid() or public.is_room_host(room_id))
  with check (user_id = auth.uid() or public.is_room_host(room_id));

-- ───────────────────────── ride_recordings ─────────────────────────
alter table public.ride_recordings enable row level security;

create policy "read own recordings" on public.ride_recordings
  for select to authenticated using (user_id = auth.uid());

create policy "insert own recordings" on public.ride_recordings
  for insert to authenticated with check (user_id = auth.uid());

create policy "update own recordings" on public.ride_recordings
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ───────────────────────── ride_stats ─────────────────────────
alter table public.ride_stats enable row level security;

create policy "read own stats" on public.ride_stats
  for select to authenticated
  using (exists (select 1 from public.ride_recordings r
                 where r.id = recording_id and r.user_id = auth.uid()));

create policy "upsert own stats (insert)" on public.ride_stats
  for insert to authenticated
  with check (exists (select 1 from public.ride_recordings r
                      where r.id = recording_id and r.user_id = auth.uid()));

create policy "upsert own stats (update)" on public.ride_stats
  for update to authenticated
  using (exists (select 1 from public.ride_recordings r
                 where r.id = recording_id and r.user_id = auth.uid()));

-- ───────────────────────── shared_music_links ─────────────────────────
alter table public.shared_music_links enable row level security;

create policy "members read music" on public.shared_music_links
  for select to authenticated using (public.is_room_member(room_id));

-- Any member can share a link (host-only could be enforced client-side / future).
create policy "members share music" on public.shared_music_links
  for insert to authenticated with check (user_id = auth.uid() and public.is_room_member(room_id));

create policy "host updates music" on public.shared_music_links
  for update to authenticated using (public.is_room_host(room_id)) with check (public.is_room_host(room_id));

-- ───────────────────────── quick_messages ─────────────────────────
alter table public.quick_messages enable row level security;

create policy "members read quick msgs" on public.quick_messages
  for select to authenticated using (public.is_room_member(room_id));

create policy "members send quick msgs" on public.quick_messages
  for insert to authenticated with check (user_id = auth.uid() and public.is_room_member(room_id));
