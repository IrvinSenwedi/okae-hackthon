import { readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';

// Real embedded PostgreSQL; only the Supabase Auth schema/UID helper is emulated.
// This validates SQL/RLS serially, not hosted Auth, PostgREST, or concurrency.
const database = new PGlite();
try {
  await database.exec(`
    create role anon nologin;
    create role authenticated nologin;
    create schema auth;
    create table auth.users(id uuid primary key, aud text, role text, is_anonymous boolean);
    create function auth.uid() returns uuid language sql stable as
      $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
    grant usage on schema auth, public to anon, authenticated;
    grant execute on function auth.uid() to public;
  `);
  const migration = await readFile(new URL('../../supabase/migrations/202610300001_passenger_signals.sql', import.meta.url), 'utf8');
  const tests = await readFile(new URL('../../supabase/tests/passenger_signals.sql', import.meta.url), 'utf8');
  await database.exec(migration);
  const results = await database.exec(tests);
  console.log(results.at(-1).rows[0].result);
} catch (error) {
  console.error(error.message);
  if (error.detail) console.error(error.detail);
  if (error.where) console.error(error.where);
  process.exitCode = 1;
} finally {
  await database.close();
}
