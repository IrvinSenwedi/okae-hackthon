-- Batch 2: private, singleton passenger signals. Deploy as migration owner.
begin;

create table public.passenger_signals (
  passenger_id uuid primary key references auth.users(id) on delete cascade,
  id uuid not null unique,
  latitude double precision,
  longitude double precision,
  accuracy_m double precision,
  status text not null check (status in ('active', 'cancelled')),
  created_at timestamptz not null,
  expires_at timestamptz not null,
  constraint signal_latitude check (latitude between -90 and 90),
  constraint signal_longitude check (longitude between -180 and 180),
  constraint signal_accuracy check (accuracy_m >= 0 and accuracy_m < 'Infinity'::double precision),
  constraint signal_coordinates check (
    (status = 'active' and latitude is not null and longitude is not null)
    or (status = 'cancelled' and latitude is null and longitude is null and accuracy_m is null)
  ),
  constraint signal_duration check (expires_at = created_at + interval '5 minutes')
);
alter table public.passenger_signals enable row level security;
revoke all on public.passenger_signals from public, anon, authenticated;
grant select on public.passenger_signals to authenticated;
create policy passenger_reads_own_unexpired_signal on public.passenger_signals
  for select to authenticated using (
    passenger_id = (select auth.uid()) and status = 'active' and expires_at > statement_timestamp()
  );
-- No INSERT/UPDATE/DELETE grants or policies. All mutations use bounded RPCs.
-- No Realtime publication; driver mode receives no access in Batch 2.

create function public.get_current_signal()
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_now timestamptz;
  v_row public.passenger_signals%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_uid::text, 0));
  v_now := clock_timestamp();
  -- Keep only a coordinate-free idempotency tombstone after expiry.
  update public.passenger_signals set status = 'cancelled', latitude = null,
    longitude = null, accuracy_m = null
    where passenger_id = v_uid and expires_at <= v_now and status = 'active';
  select * into v_row from public.passenger_signals
    where passenger_id = v_uid and status = 'active' and expires_at > v_now;
  return jsonb_build_object('server_now', v_now, 'signal',
    case when found then to_jsonb(v_row) else null end);
end;
$$;

create function public.create_passenger_signal(
  p_request_id uuid, p_latitude double precision, p_longitude double precision,
  p_accuracy_m double precision default null
) returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_now timestamptz;
  v_row public.passenger_signals%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if p_request_id is null or p_latitude is null or p_longitude is null
    or not (p_latitude between -90 and 90) or not (p_longitude between -180 and 180)
    or (p_accuracy_m is not null and not (p_accuracy_m >= 0 and p_accuracy_m < 'Infinity'::double precision))
    then raise exception 'Invalid signal coordinates' using errcode = '22023'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_uid::text, 0));
  v_now := clock_timestamp();
  select * into v_row from public.passenger_signals where passenger_id = v_uid;
  if found then
    -- Replaying this request never restarts its five-minute lifetime.
    if v_row.id = p_request_id or (v_row.status = 'active' and v_row.expires_at > v_now) then
      return public.get_current_signal();
    end if;
  end if;
  insert into public.passenger_signals as existing
    (passenger_id, id, latitude, longitude, accuracy_m, status, created_at, expires_at)
    values (v_uid, p_request_id, p_latitude, p_longitude, p_accuracy_m, 'active', v_now, v_now + interval '5 minutes')
    on conflict (passenger_id) do update set
      id = excluded.id, latitude = excluded.latitude, longitude = excluded.longitude,
      accuracy_m = excluded.accuracy_m, status = excluded.status,
      created_at = excluded.created_at, expires_at = excluded.expires_at
    returning * into v_row;
  return jsonb_build_object('server_now', clock_timestamp(), 'signal', to_jsonb(v_row));
end;
$$;

create function public.cancel_passenger_signal(p_signal_id uuid)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_uid::text, 0));
  if not exists (select 1 from public.passenger_signals where passenger_id = v_uid and id = p_signal_id)
    then raise exception 'Signal does not belong to this passenger' using errcode = '42501'; end if;
  update public.passenger_signals set status = 'cancelled', latitude = null,
    longitude = null, accuracy_m = null where passenger_id = v_uid and id = p_signal_id;
  return public.get_current_signal();
end;
$$;

revoke all on function public.get_current_signal() from public, anon, authenticated;
revoke all on function public.create_passenger_signal(uuid, double precision, double precision, double precision) from public, anon, authenticated;
revoke all on function public.cancel_passenger_signal(uuid) from public, anon, authenticated;
grant execute on function public.get_current_signal() to authenticated;
grant execute on function public.create_passenger_signal(uuid, double precision, double precision, double precision) to authenticated;
grant execute on function public.cancel_passenger_signal(uuid) to authenticated;
commit;
