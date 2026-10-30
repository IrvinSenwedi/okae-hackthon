# OKAE — Passenger signalling (Batch 2)

A Flutter foundation for South African minibus taxi passenger visibility.
Batch 2 implements anonymous passenger authentication, fresh GPS activation, server-defined five-minute signals, cancellation and restoration. Driver availability and discovery remain disabled. There are no bookings, fabricated passengers, registration screens or background tracking.

**Before live signalling:** enable anonymous sign-ins in Supabase and deploy [the migration](supabase/migrations/202610300001_passenger_signals.sql). Anonymous sign-ins were disabled in the supplied project when checked on 30 October 2026. No hosted database changes have been applied.

See [Batch 2 setup, security and validation](docs/BATCH_2.md) for the full implementation and deployment instructions. The public configuration is stored only in ignored `config.local.json`; run `flutter run --dart-define-from-file=config.local.json`.

## Structure and changes

- `lib/main.dart`: environment configuration, Mapbox token setup, Supabase SDK initialization, Riverpod scope.
- `lib/app/`: app shell and ivory/charcoal/orange Material theme.
- `lib/core/config/`: typed Dart environment configuration and future 500 m / 5 minute constants.
- `lib/core/location/`: injectable Geolocator service and auto-disposed Riverpod controller. Handles disabled GPS, denied/blocked permissions, errors and explicit refresh.
- `lib/core/services/`: Supabase setup and read-only health check. Missing configuration, invalid configuration, initialization failure and connection failure are distinct states. SDK initialization alone does not prove connectivity.
- `lib/features/onboarding/`: welcome and local mode navigation.
- `lib/features/passenger/`: signal model/service, persistent request intent, Riverpod lifecycle controller and passenger UI.
- `lib/features/driver/`: disabled availability, Mapbox map, actual GPS marker and honest empty state.
- `lib/shared/widgets/`: shared status, layout and location widgets.
- `test/`: navigation, preview controls, small-screen layout, configuration and location service tests.
- Android manifest: internet and foreground coarse/fine location only.
- iOS: When In Use description, minimum iOS 14 and Podfile with Geolocator Always-permission bypass.
- `pubspec.yaml` / lockfile: compatible stable dependencies. Generated desktop plugin registration updated by Flutter; desktop map shows an unsupported-platform state.
- `.gitignore`: excludes local configuration files.

Existing native project structure and application ID were preserved.

## SDK and packages

Resolved on Flutter 3.38.7 / Dart 3.10.7:
Mapbox 3.34.1, Riverpod 3.3.2, Geolocator 14.1.2, Supabase Flutter 2.18.3, HTTP 1.6.0.
The lockfile records exact resolved versions; newer releases can require a newer Flutter SDK.

## Mapbox setup

Create a Mapbox **public** token (`pk.`) in your Mapbox account. Supply it with
`--dart-define=ACCESS_TOKEN=...`. Do not use secret tokens or commit token values.
MapboxOptions is configured before any MapWidget is created.
The implementation uses the v3 CameraViewportState API and preserves the SDK's default logo/attribution controls.

The driver must tap **Use my location** and allow foreground location before the map is created.
No invented fallback centre is used. Pan and zoom remain enabled.
A blue annotation shows the last GPS refresh; it is deliberately not a continuously tracked location puck while the driver is offline.
Tap **Refresh location** to retrieve a new coordinate and recenter the map.
Backgrounding unmounts the map; resuming restores the last explicit GPS result, not a fresh fix.
Map errors show a retry state. GPS failures remain visible in the location panel.
Android/iOS/web are map targets; iOS builds require macOS/Xcode and CocoaPods.

Official references:
- [Mapbox installation](https://docs.mapbox.com/flutter/maps/guides/install/)
- [Mapbox Flutter API](https://docs.mapbox.com/flutter/maps/api/latest/)
- [Geolocator platform setup](https://pub.dev/packages/geolocator)

## Supabase setup

Supply `SUPABASE_URL` (HTTPS project URL) and `SUPABASE_PUBLISHABLE_KEY` (public client key).
Never supply a service-role or secret key.
Missing configuration does not stop local preview navigation.
Deploy `supabase/migrations/202610300001_passenger_signals.sql` through authenticated Supabase CLI migration tooling or the project's SQL Editor. Enable anonymous sign-ins under Authentication → Sign In / Providers. These require project administration; the publishable key cannot perform them.

The migration enables RLS, grants only own/unexpired SELECT access, and restricts mutation to authenticated RPCs. No raw table writes or Realtime publication are enabled. Supabase Flutter persists sessions using its default local storage, with automatic token refreshing enabled. See [security and test details](docs/BATCH_2.md).

`initializeBackend` reports SDK setup separately from network health.
`checkBackendConnection` / `connectionProvider` can check GET /auth/v1/health without touching signal tables.
A successful health check confirms only service reachability, not future authentication or database authorization.
No health request runs unless the provider/function is explicitly invoked.
See [Supabase Flutter setup](https://supabase.com/docs/guides/getting-started/quickstarts/flutter).

## Run

Without credentials, explore the honest configuration/error states:

```powershell
flutter pub get
flutter run -d emulator-5554
```

With your own public configuration:

```powershell
flutter run -d emulator-5554 --dart-define=ACCESS_TOKEN=YOUR_PUBLIC_MAPBOX_TOKEN --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLIC_KEY
```

Alternatively create ignored `config.local.json` containing those three keys, then run
`flutter run --dart-define-from-file=config.local.json`.
Dart defines are compiled into the app, so only public client configuration belongs here.
Restart/rebuild after changing defines.

## Batch 1 verification history (30 October 2026)

- `flutter pub get`: succeeded through dependency installation.
- Initial `flutter test`: **10 tests passed**, including navigation, preview safeguards, 320 px layout and mocked permission/GPS refresh cases.
- `flutter analyze`: **no issues** after lint fixes and backend health preparation.
- A subsequent test run was interrupted by an OS disk-full error while compiling output.dill. The final backend health additions therefore require a fresh test run.
- `flutter build apk --debug`: **failed**. Gradle reported **There is not enough space on the disk**, including failed cache JAR transforms. Flutter additionally emitted an AGP 9 compatibility advisory; after freeing space, rerun to determine whether this is an independent blocker.
- Android emulator detected (Android 17 / API 37), but build failure prevented installing/running this app.
- No valid Mapbox token or Supabase configuration was provided. Live map initialization, GPS on a device, actual network failures, attribution rendering and gesture behavior remain **unverified**.
- iOS build/runtime not executed on this Windows machine.
- Only this project's generated build directory was removed after disk exhaustion. No shared SDK/Gradle caches or unrelated files were deleted.

After freeing disk space:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter run -d emulator-5554 --dart-define-from-file=config.local.json
```

Device checks: deny/allow/block permission; disable/enable GPS; refresh at two actual locations; verify blue marker and recentering; pan/zoom and attribution; background/resume; invalid token/offline map retry; back navigation. A mock/unit test cannot prove native Mapbox initialization.

## Next batches

Batch 2 client implementation and versioned database migration are present. Deploy the migration and enable anonymous authentication before live acceptance testing. Driver availability remains disabled.
Actual 500-metre discovery/filtering remains Batch 3. No acceptance, destinations, seats, payments, chat or taxi route calculations are included.

## Follow-up verification

The supplied Mapbox public token is stored only in ignored config.local.json. A later Android debug build succeeded, installed and launched on emulator-5554 using that configuration. All 10 tests passed again. Native map rendering after granting GPS permission has not yet been verified; the earlier disk-space build blocker was resolved before this successful run.
