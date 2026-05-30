-- RideTalk — RPC helpers (atomic create/join + host actions)
-- Apply after 0002_rls.sql

-- Unique 6-char join code (no ambiguous chars).
create or replace function public.generate_room_code()
returns text language plpgsql as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  code text; i int;
begin
  loop
    code := '';
    for i in 1..6 loop
      code := code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.ride_rooms where ride_rooms.code = code);
  end loop;
  return code;
end; $$;

-- create_room: room + host membership, sets caller as host & initial lead rider.
create or replace function public.create_room(
  p_name text default 'Group Ride',
  p_threshold numeric default 1.0
)
returns public.ride_rooms
language plpgsql security definer set search_path = public as $$
declare v_room public.ride_rooms;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;

  insert into public.ride_rooms (code, name, host_id, lead_rider_id, status, separation_threshold_miles)
  values (public.generate_room_code(),
          coalesce(nullif(p_name,''),'Group Ride'),
          auth.uid(), auth.uid(), 'active',
          coalesce(p_threshold, 1.0))
  returning * into v_room;

  insert into public.room_members (room_id, user_id, role)
  values (v_room.id, auth.uid(), 'host')
  on conflict (room_id, user_id) do update set left_at = null, role = 'host';

  return v_room;
end; $$;

-- join_room by code.
create or replace function public.join_room(p_code text)
returns public.ride_rooms
language plpgsql security definer set search_path = public as $$
declare v_room public.ride_rooms;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;

  select * into v_room from public.ride_rooms
  where code = upper(trim(p_code)) and status = 'active' limit 1;

  if v_room.id is null then raise exception 'room not found or not active'; end if;

  insert into public.room_members (room_id, user_id, role, left_at)
  values (v_room.id, auth.uid(), 'rider', null)
  on conflict (room_id, user_id) do update set left_at = null;

  return v_room;
end; $$;

create or replace function public.leave_room(p_room_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.room_members set left_at = now()
  where room_id = p_room_id and user_id = auth.uid();
  -- mark our location disconnected so others see "last known"
  update public.live_locations set is_connected = false
  where room_id = p_room_id and user_id = auth.uid();
end; $$;

create or replace function public.end_room(p_room_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_room_host(p_room_id) then raise exception 'only the host can end the room'; end if;
  update public.ride_rooms set status = 'ended', ended_at = now() where id = p_room_id;
end; $$;

-- Host assigns the lead rider (ride leader mode).
create or replace function public.set_lead_rider(p_room_id uuid, p_user_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_room_host(p_room_id) then raise exception 'only the host can set the lead rider'; end if;
  update public.ride_rooms set lead_rider_id = p_user_id where id = p_room_id;
end; $$;

-- Host sets the separation-alert threshold (miles).
create or replace function public.set_separation_threshold(p_room_id uuid, p_miles numeric)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_room_host(p_room_id) then raise exception 'only the host can set the threshold'; end if;
  update public.ride_rooms set separation_threshold_miles = greatest(0.1, p_miles) where id = p_room_id;
end; $$;

grant execute on function public.create_room(text, numeric)        to authenticated;
grant execute on function public.join_room(text)                   to authenticated;
grant execute on function public.leave_room(uuid)                  to authenticated;
grant execute on function public.end_room(uuid)                    to authenticated;
grant execute on function public.set_lead_rider(uuid, uuid)        to authenticated;
grant execute on function public.set_separation_threshold(uuid, numeric) to authenticated;
