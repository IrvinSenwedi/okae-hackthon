# Batch 2: passenger signalling

## Implementation

Work remains on `dev`; no commits or pushes were made.
Existing design, local navigation, Mapbox driver map and foreground location service are preserved.
Driver mode neither fetches passenger signals nor enables availability.

Changed/new app files:

- `lib/core/services/backend.dart`: automatic token refresh enabled; default Supabase Flutter persisted-session storage retained.
- `lib/core/services/passenger_auth.dart`: saved-session reuse, anonymous sign-in, single-flight authentication, refresh handling and auth-state/error subscription. Refresh failure never falls through into making a different account.
- `lib/core/location/location_controller.dart`: shared fresh/permission-checked foreground GPS method, actionable failures, truthful location copy.
- `lib/features/passenger/data/signal_service.dart`: create/get/cancel RPC adapter, server-time response model and durable request-intent store.
- `lib/features/passenger/application/signal_controller.dart`: idle/getting-location/activating/active/cancelling/cancelled/expired/error, duplicate-tap guard, timeout reconciliation, restore and lifecycle handling.
- `lib/features/passenger/passenger_screen.dart`: activation, countdown, cancel, expired/cancelled states and retryable errors using the existing visual identity.
- `supabase/migrations/202610300001_passenger_signals.sql`: private singleton signal table and bounded functions.
- `supabase/tests/passenger_signals.sql`: transactional database/security assertions.
- `tools/database/`: reproducible embedded PostgreSQL test runner and locked development dependency. Not used by Flutter.
- `test/`: auth, location, RPC adapter, controller and widget coverage.
- `pubspec.yaml` / lockfile: direct dependencies on already-resolved `shared_preferences` and `uuid`.
- `.gitignore`: local configuration and test-engine node_modules stay excluded.

## Required project setup

The provided project URL/public client key and existing Mapbox token were added to ignored `config.local.json`.
No private, service-role, management or database credentials are needed in the mobile app.

1. In the intended Supabase project, open **Authentication → Sign In / Providers → Anonymous Sign-Ins** (dashboard wording may vary). Enable anonymous sign-ins and save.
   A read-only GET /auth/v1/settings check on 30 October 2026 reported anonymous users **disabled**. This setting was not changed by the implementation.
2. Deploy the migration after reviewing it. Use a project administrator's SQL Editor to execute the entire migration file once, or the normal authenticated CLI migration workflow.
   The publishable key cannot deploy DDL or change Auth settings.
3. Do not add `passenger_signals` to a Realtime publication or expose broad SELECT/UPDATE policies.
4. Run/restart with the local Dart defines, open passenger mode and allow foreground location when activating.

For a CLI-managed project, using an installed Supabase CLI and administrator login:

```powershell
supabase login
supabase init
supabase link --project-ref rmbaufatozpmuuirgmat
supabase db push --dry-run
supabase db push
```

Run `supabase init` only if this checkout has not yet been initialized. Review the dry run and linked project before pushing.
If SQL Editor deployment is used instead, record/reconcile migration history before adopting CLI pushes; do not blindly rerun the table-creation migration.
No hosted SQL, Auth setting changes, real coordinate writes or live sign-ins were performed during this implementation.

Supabase recommends abuse controls for anonymous sign-ins. If CAPTCHA is enabled in the project, the current MVP needs a token collection flow before live use; it does not bypass that setting.
Anonymous identities are recoverable only while the saved app session remains: uninstalling/clearing app storage loses that identity. Any old signal still expires after five minutes.

## Database security and data lifetime

`passenger_id` is the table primary key and references `auth.users`. There can be only one stored row per passenger, so concurrent calls cannot create multiple active rows.
Functions also serialize per passenger with a transaction advisory lock.

Authenticated anonymous users have the `authenticated` role; this is different from unauthenticated `anon` traffic.
RLS allows an authenticated passenger to select only their own **active and unexpired** row.
There are no client INSERT/UPDATE/DELETE privileges or policies.
The migration does not grant driver discovery or publish coordinates to Realtime.

The only mutation API is:

- `create_passenger_signal(p_request_id, p_latitude, p_longitude, p_accuracy_m)`
- `cancel_passenger_signal(p_signal_id)`

`get_current_signal()` returns the owner's unexpired signal and server time.
Every trusted function uses `SECURITY DEFINER SET search_path = ''`, schema-qualified table references and its own `auth.uid()` check. PUBLIC/anon EXECUTE is revoked; only authenticated users get EXECUTE.
There is no passenger-ID, creation-time or expiry-time input for a client to spoof.
Coordinates and accuracy are validated, including non-finite values.
Timestamps are generated by PostgreSQL; expiry is exactly created_at + five minutes, backed by a table constraint.

A duplicate active activation returns the existing row without extending it.
Replaying the current request ID after cancellation/expiry does not reactivate it.
New activation after cancellation/expiry replaces that passenger's single row.
Cancellation immediately removes coordinates.
Expired rows are excluded by RLS and every active RPC query, even if stored status still says active.
Expired coordinates are lazily scrubbed when that passenger next calls get/create/cancel. Without a cleanup job, the latest expired row may remain stored until that visit; there is no growing location history.
Cancelled/expired request IDs remain as coordinate-free tombstones for retry safety.
A recurring server purge can be added later if a stricter physical data-retention deadline is required; it is not needed for active-state correctness.

The SQL test suite checks passenger isolation, cross-passenger cancellation rejection, missing-session denial, denied raw writes/expiry manipulation, coordinate validation, fixed duration, idempotency, cancellation scrubbing and reuse after expiry.

## Client behaviour and recovery

Entering passenger mode authenticates once/reuses the saved session and restores server state.
SIGNAL TAXI is enabled only after successful restoration.
Creation performs a fresh permission check and GPS acquisition; it does not reuse the displayed cached coordinate.
No GPS stream or background tracking is started.
The app never displays an activation as successful until a server response confirms an active row.

Mutations use a durable UUID intent stored under the authenticated passenger ID; local storage holds no signal coordinates.
Rapid taps are ignored while an operation is in progress.
After a failed/timed-out mutation, the controller reads actual server state.
If reconciliation also fails, creation is blocked and **Check status** is offered.
Uncertain activation retries reuse the saved request ID; an unconfirmed cancellation retains the original signal/cancel intent.
Navigation keeps the controller alive; process restart fetches the server record and recovers any request intent.

Every RPC response carries `server_now` and server-defined `expires_at`.
The countdown uses their difference, subtracts the full request round trip conservatively, caps at five minutes and advances with a monotonic stopwatch.
Changing the device wall clock cannot extend it.
On resume, the controller revalidates with the server; pending/uncertain state is not shown as a confirmed active signal.
The countdown is approximate and can end slightly early because of the conservative latency allowance; server RLS remains authoritative.
Cancellation is never presented as successful solely because a local button was tapped.

The UI says the waiting location is stored but driver delivery/discovery is not enabled. No claim that a taxi driver has been notified is made.

## Run and validate

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --dart-define-from-file=config.local.json
flutter run -d emulator-5554 --dart-define-from-file=config.local.json
```

The ignored JSON should contain:
```json
{
  "ACCESS_TOKEN": "YOUR_PUBLIC_MAPBOX_TOKEN",
  "SUPABASE_URL": "https://YOUR_PROJECT.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "YOUR_PUBLIC_CLIENT_KEY"
}
```

Embedded SQL tests (Node.js and npm, no Docker/PostgreSQL install needed):

```powershell
npm --prefix tools/database ci
npm --prefix tools/database test
```

This executes the unmodified migration and SQL test file in PGlite's PostgreSQL engine.
Only the Auth users schema, roles and auth.uid() helper are emulated.
It validates serial SQL/RLS behaviour, not Supabase Auth, the hosted PostgREST gateway, multi-connection concurrency or actual network policy.

For a disposable local Supabase database with the migration already applied:

```powershell
psql -v ON_ERROR_STOP=1 "$env:LOCAL_DATABASE_URL" -f supabase/tests/passenger_signals.sql
```

Use only a disposable test database: fixtures are transactional and rolled back, but the runner intentionally assumes administrative access.
Full local Supabase CLI/PostgreSQL tests require their tooling and runtime (not present in this environment).

Live acceptance after deployment: activate at an actual permitted location; verify the owner's row and server timestamps; navigate away/back; restart with the same saved session; wait five minutes; reactivate; cancel; simulate network loss during both writes and check reconciliation. Use a separate authenticated passenger session to verify cross-user reads/writes are denied. Confirm driver mode remains empty/offline.
Do not clear app data between tests intended to verify session preservation.

## Evidence and limits (30 October 2026)

- Flutter static analysis: **no issues**.
- Flutter automated suite: **37 tests passed**. Auth/network/GPS are mocked; restart tests construct a new controller against the same fake backend. UI tests cover actual passenger controls and navigation.
- Embedded PostgreSQL: migration and all transactional SQL security assertions **passed**, fixtures rolled back.
- Android debug build with the local public configuration: **succeeded**.
- Read-only hosted Auth settings check: anonymous sign-ins **disabled**.
- Hosted migration deployment, real anonymous sign-in, real signal activation/cancellation, persistent-session device restart and hosted RLS tests: **not executed**.
- iOS runtime/build and device GPS/Mapbox rendering: not revalidated in Batch 2.

The code and migration are ready for deployment/review; the live Batch 2 completion criteria remain pending the two administrative setup steps and live acceptance checks.
Batch 3 driver authorisation and server-side 500-metre discovery are not implemented.

Official references:
- [Anonymous sign-ins](https://supabase.com/docs/guides/auth/auth-anonymous)
- [Auth state changes and refresh errors](https://supabase.com/docs/reference/dart/auth-onauthstatechange)
- [RLS](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Database function security](https://supabase.com/docs/guides/database/functions)
- [Embedded PostgreSQL test API](https://pglite.dev/docs/api)
