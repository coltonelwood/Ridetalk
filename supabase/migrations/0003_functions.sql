-- RideTalk — RPC helpers
-- Apply after 0002_rls.sql
--
-- These are SECURITY DEFINER RPCs the app calls for atomic create/join flows so
-- the client doesn't have to do multi-step inserts.

-- ─────────────────────────────────────────────────────────────────────────────
-- generate a unique 6-char uppercase room code (no ambiguous chars)
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.generate_room_code()
returns text
language plpgsql
as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; -- no I,O,0,1
  code text;
  i int;
begin
  loop
    code := '';
    for i in 1..6 loop
      code := code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.rooms where rooms.code = code);
  end loop;
  return code;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- create_room: makes a room + adds caller as host member, returns the room row
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.create_room(p_name text default 'Group Ride')
returns public.rooms
language plpgsql
security definer set search_path = public
as $$
declare
  v_room public.rooms;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  insert into public.rooms (code, name, host_id, status)
  values (public.generate_room_code(), coalesce(nullif(p_name, ''), 'Group Ride'), auth.uid(), 'active')
  returning * into v_room;

  insert into public.room_members (room_id, user_id, role)
  values (v_room.id, auth.uid(), 'host')
  on conflict (room_id, user_id) do update set left_at = null, role = 'host';

  return v_room;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- join_room: join an active room by code, returns the room row
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.join_room(p_code text)
returns public.rooms
language plpgsql
security definer set search_path = public
as $$
declare
  v_room public.rooms;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select * into v_room
  from public.rooms
  where code = upper(trim(p_code))
    and status = 'active'
  limit 1;

  if v_room.id is null then
    raise exception 'room not found or not active';
  end if;

  insert into public.room_members (room_id, user_id, role, left_at)
  values (v_room.id, auth.uid(), 'rider', null)
  on conflict (room_id, user_id)
    do update set left_at = null;

  return v_room;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- leave_room: mark caller as left
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.leave_room(p_room_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  update public.room_members
  set left_at = now()
  where room_id = p_room_id and user_id = auth.uid();
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- end_room: host ends the ride
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.end_room(p_room_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.is_room_host(p_room_id) then
    raise exception 'only the host can end the room';
  end if;

  update public.rooms
  set status = 'ended', ended_at = now()
  where id = p_room_id;
end;
$$;

-- Allow authenticated users to execute these RPCs.
grant execute on function public.create_room(text)  to authenticated;
grant execute on function public.join_room(text)    to authenticated;
grant execute on function public.leave_room(uuid)   to authenticated;
grant execute on function public.end_room(uuid)     to authenticated;
