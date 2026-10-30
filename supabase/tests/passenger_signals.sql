-- Run only on a disposable local Supabase database after the migration.
-- psql -v ON_ERROR_STOP=1 "$env:LOCAL_DATABASE_URL" -f supabase/tests/passenger_signals.sql
-- Every fixture and mutation is rolled back. No extensions required.
begin;
insert into auth.users(id, aud, role, is_anonymous) values
  ('10000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', true),
  ('10000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', true);

create function pg_temp.check_true(p_condition boolean, p_message text)
returns void language plpgsql as $$
begin if p_condition is distinct from true then raise exception 'FAIL: %', p_message; end if; end;
$$;

-- Anonymous Auth users use authenticated; unauthenticated traffic uses anon.
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', true);
select public.create_passenger_signal('20000000-0000-0000-0000-000000000002', -26.2, 28.0, 5);

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select pg_temp.check_true((select count(*) = 0 from public.passenger_signals), 'A cannot read B coordinates');
select public.create_passenger_signal('20000000-0000-0000-0000-000000000001', -26.1, 28.1, null);
select pg_temp.check_true((select count(*) = 1 from public.passenger_signals), 'A reads only own signal');
select pg_temp.check_true((select expires_at = created_at + interval '5 minutes' from public.passenger_signals), 'server lifetime exactly five minutes');

-- Duplicate active request keeps the original ID and original expiry.
select pg_temp.check_true(
  public.create_passenger_signal('20000000-0000-0000-0000-000000000099', 1, 1, 1)->'signal'->>'id' = '20000000-0000-0000-0000-000000000001',
  'second activation cannot replace or extend active signal');

do $$
begin
  begin
    perform public.cancel_passenger_signal('20000000-0000-0000-0000-000000000002');
    raise exception 'FAIL: A cancelled B';
  exception when insufficient_privilege then null; end;
  begin
    update public.passenger_signals set expires_at = now() + interval '1 day';
    raise exception 'FAIL: arbitrary expiry update allowed';
  exception when insufficient_privilege then null; end;
  begin
    delete from public.passenger_signals;
    raise exception 'FAIL: arbitrary delete allowed';
  exception when insufficient_privilege then null; end;
  begin
    insert into public.passenger_signals(passenger_id, id, latitude, longitude, status, created_at, expires_at)
    values ('10000000-0000-0000-0000-000000000002', gen_random_uuid(), 1, 1, 'active', now(), now() + interval '1 day');
    raise exception 'FAIL: direct insert with spoofed owner/expiry allowed';
  exception when insufficient_privilege then null; end;
  begin
    perform public.create_passenger_signal(gen_random_uuid(), 91, 1, 1);
    raise exception 'FAIL: invalid latitude allowed';
  exception when invalid_parameter_value then null; end;
  begin
    perform public.create_passenger_signal(gen_random_uuid(), 1, 181, 1);
    raise exception 'FAIL: invalid longitude allowed';
  exception when invalid_parameter_value then null; end;
  begin
    perform public.create_passenger_signal(gen_random_uuid(), 1, 1, -1);
    raise exception 'FAIL: negative accuracy allowed';
  exception when invalid_parameter_value then null; end;
end;
$$;
select public.cancel_passenger_signal('20000000-0000-0000-0000-000000000001');
select pg_temp.check_true(public.get_current_signal()->'signal' = 'null'::jsonb, 'cancelled excluded from active');
select pg_temp.check_true(public.create_passenger_signal('20000000-0000-0000-0000-000000000001', 1, 1, 1)->'signal' = 'null'::jsonb, 'replayed cancelled request cannot reactivate');
select public.create_passenger_signal('30000000-0000-0000-0000-000000000001', 1, 1, 1);

reset role;
-- Force expiry as administrator, preserving the lifetime constraint.
update public.passenger_signals set created_at = now() - interval '6 minutes',
  expires_at = now() - interval '1 minute'
  where passenger_id = '10000000-0000-0000-0000-000000000001';
set local role authenticated;
select pg_temp.check_true((select count(*) = 0 from public.passenger_signals), 'RLS excludes expired row even with active stored status');
select pg_temp.check_true(public.get_current_signal()->'signal' = 'null'::jsonb, 'RPC excludes expired signal');
select public.create_passenger_signal('40000000-0000-0000-0000-000000000001', 2, 2, 2);
select pg_temp.check_true((select count(*) = 1 from public.passenger_signals), 'new signal allowed after expiry');
select public.cancel_passenger_signal('40000000-0000-0000-0000-000000000001');

select set_config('request.jwt.claim.sub', '', true);
do $$
begin
  begin
    perform public.get_current_signal();
    raise exception 'FAIL: authenticated role without user ID allowed';
  exception when insufficient_privilege then null; end;
end;
$$;

reset role;
select pg_temp.check_true((select count(*) = 1 from public.passenger_signals where passenger_id = '10000000-0000-0000-0000-000000000001'), 'only one row per passenger, no accumulated history');
select pg_temp.check_true((select latitude is null and longitude is null and accuracy_m is null from public.passenger_signals where passenger_id = '10000000-0000-0000-0000-000000000001'), 'cancel scrubs coordinates');
select pg_temp.check_true((select status = 'active' from public.passenger_signals where passenger_id = '10000000-0000-0000-0000-000000000002'), 'B unaffected by A mutations');

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
do $$
begin
  begin
    perform * from public.passenger_signals;
    raise exception 'FAIL: unauthenticated coordinates accessible';
  exception when insufficient_privilege then null; end;
  begin
    perform public.get_current_signal();
    raise exception 'FAIL: unauthenticated RPC allowed';
  exception when insufficient_privilege then null; end;
  begin
    perform public.create_passenger_signal(gen_random_uuid(), 1, 1, 1);
    raise exception 'FAIL: unauthenticated create allowed';
  exception when insufficient_privilege then null; end;
end;
$$;
reset role;
rollback;
select 'Passenger signal security tests passed (fixtures rolled back)' as result;
