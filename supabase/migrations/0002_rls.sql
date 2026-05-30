-- RideTalk — Row Level Security
-- Apply after 0001_init.sql
--
-- Principle: a rider can only see/touch rooms they belong to. Only the host can
-- mutate host-only fields (mute/remove others, end the room).

-- ─────────────────────────────────────────────────────────────────────────────
-- Helper: is the current user a member of a room?
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.is_room_member(p_room_id uuid)
returns boolean
language sql
security definer set search_path = public
stable
as $$
  select exists (
    select 1 from public.room_members m
    where m.room_id = p_room_id
      and m.user_id = auth.uid()
      and m.left_at is null
  );
$$;

-- Helper: is the current user the host of a room?
create or replace function public.is_room_host(p_room_id uuid)
returns boolean
language sql
security definer set search_path = public
stable
as $$
  select exists (
    select 1 from public.rooms r
    where r.id = p_room_id
      and r.host_id = auth.uid()
  );
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- profiles
-- ─────────────────────────────────────────────────────────────────────────────
alter table public.profiles enable row level security;

-- Anyone authenticated can read profiles (needed to render rosters/avatars).
create policy "profiles are readable by authenticated users"
  on public.profiles for select
  to authenticated
  using (true);

-- You can only insert/update your own profile.
create policy "users manage their own profile (insert)"
  on public.profiles for insert
  to authenticated
  with check (id = auth.uid());

create policy "users manage their own profile (update)"
  on public.profiles for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────
-- rooms
-- ─────────────────────────────────────────────────────────────────────────────
alter table public.rooms enable row level security;

-- Read a room if you're a member OR you're looking it up to join (by code) —
-- we allow authenticated read of active rooms so the join-by-code flow works.
create policy "members and joiners can read rooms"
  on public.rooms for select
  to authenticated
  using (
    status = 'active'
    or host_id = auth.uid()
    or public.is_room_member(id)
  );

-- Any authenticated user can create a room they host.
create policy "users can create rooms they host"
  on public.rooms for insert
  to authenticated
  with check (host_id = auth.uid());

-- Only the host can update (rename / end) the room.
create policy "host can update their room"
  on public.rooms for update
  to authenticated
  using (host_id = auth.uid())
  with check (host_id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────
-- room_members
-- ─────────────────────────────────────────────────────────────────────────────
alter table public.room_members enable row level security;

-- Members can read the roster of their rooms.
create policy "members can read their room roster"
  on public.room_members for select
  to authenticated
  using (public.is_room_member(room_id) or public.is_room_host(room_id));

-- A user can add themselves to a room (join). Host rows are created by the
-- create-room flow which also inserts the host as a member.
create policy "users can join rooms (add themselves)"
  on public.room_members for insert
  to authenticated
  with check (user_id = auth.uid());

-- A user can update their own membership (e.g. leave -> set left_at, self-mute).
create policy "users can update their own membership"
  on public.room_members for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- The host can update any membership in their room (mute/remove others).
create policy "host can moderate members"
  on public.room_members for update
  to authenticated
  using (public.is_room_host(room_id))
  with check (public.is_room_host(room_id));

-- The host can delete members (remove from room).
create policy "host can remove members"
  on public.room_members for delete
  to authenticated
  using (public.is_room_host(room_id));

-- ─────────────────────────────────────────────────────────────────────────────
-- music_states
-- ─────────────────────────────────────────────────────────────────────────────
alter table public.music_states enable row level security;

create policy "members can read music state"
  on public.music_states for select
  to authenticated
  using (public.is_room_member(room_id));

-- Host controls the shared track in MVP.
create policy "host can upsert music state (insert)"
  on public.music_states for insert
  to authenticated
  with check (public.is_room_host(room_id) and updated_by = auth.uid());

create policy "host can upsert music state (update)"
  on public.music_states for update
  to authenticated
  using (public.is_room_host(room_id))
  with check (public.is_room_host(room_id));

-- ─────────────────────────────────────────────────────────────────────────────
-- ride_locations
-- ─────────────────────────────────────────────────────────────────────────────
alter table public.ride_locations enable row level security;

-- Members can read everyone's pings in their room.
create policy "members can read room locations"
  on public.ride_locations for select
  to authenticated
  using (public.is_room_member(room_id));

-- A user can only insert their own pings, and only into rooms they're in.
create policy "users insert their own locations"
  on public.ride_locations for insert
  to authenticated
  with check (user_id = auth.uid() and public.is_room_member(room_id));
