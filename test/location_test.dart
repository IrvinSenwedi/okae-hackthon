import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:okae/core/location/location_controller.dart';
import 'package:okae/core/config/app_config.dart';
import 'package:okae/core/services/backend.dart';

class FakeLocation extends LocationService {
  bool enabled = true, fails = false;
  LocationPermission permission = LocationPermission.whileInUse;
  int calls = 0;
  double latitude = -26.2;
  @override
  Future<bool> servicesEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async => permission;
  @override
  Future<Position> currentPosition() async {
    calls++;
    if (fails) throw Exception('GPS failed');
    return Position(
      latitude: latitude,
      longitude: 28.0,
      timestamp: DateTime(2026),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

void main() {
  late FakeLocation service;
  late ProviderContainer container;
  setUp(() {
    service = FakeLocation();
    container = ProviderContainer(
      overrides: [locationServiceProvider.overrideWithValue(service)],
    );
    container.listen(locationProvider, (_, _) {});
  });
  tearDown(() => container.dispose());
  Future<void> refresh() => container.read(locationProvider.notifier).refresh();
  test('services disabled never requests position', () async {
    service.enabled = false;
    await refresh();
    expect(
      container.read(locationProvider).status,
      LocationStatus.servicesDisabled,
    );
    expect(service.calls, 0);
  });
  for (final permission in [
    LocationPermission.denied,
    LocationPermission.deniedForever,
  ]) {
    test('handles $permission', () async {
      service.permission = permission;
      await refresh();
      expect(
        container.read(locationProvider).status,
        permission == LocationPermission.denied
            ? LocationStatus.denied
            : LocationStatus.deniedForever,
      );
      expect(service.calls, 0);
    });
  }
  test('GPS errors recover', () async {
    service.fails = true;
    await refresh();
    expect(container.read(locationProvider).status, LocationStatus.error);
    service.fails = false;
    await refresh();
    expect(container.read(locationProvider).status, LocationStatus.ready);
  });
  test(
    'explicit refresh updates position without automatic tracking',
    () async {
      expect(service.calls, 0);
      await refresh();
      expect(container.read(locationProvider).position!.latitude, -26.2);
      service.latitude = -26.3;
      await refresh();
      expect(container.read(locationProvider).position!.latitude, -26.3);
      expect(service.calls, 2);
    },
  );
  test('configuration guards', () async {
    expect(
      await initializeBackend(const AppConfig()),
      BackendStatus.missingConfiguration,
    );
    expect(
      await initializeBackend(
        const AppConfig(supabaseUrl: 'bad', supabaseKey: 'public'),
      ),
      BackendStatus.invalidConfiguration,
    );
    expect(const AppConfig(mapboxToken: 'sk.secret').hasMapbox, false);
    expect(AppConfig.signalRadiusMetres, 500);
    expect(AppConfig.signalDuration, const Duration(minutes: 5));
  });
}
