import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

enum LocationStatus {
  idle,
  loading,
  ready,
  servicesDisabled,
  denied,
  deniedForever,
  error,
}

class LocationState {
  const LocationState(this.status, {this.position});
  final LocationStatus status;
  final Position? position;
  String get message => switch (status) {
    LocationStatus.idle =>
      'Get a location fix here. Activating a signal shares one waiting location.',
    LocationStatus.loading => 'Finding your current location…',
    LocationStatus.ready =>
      'Location fix available. Activating a signal always requests a fresh fix.',
    LocationStatus.servicesDisabled =>
      'Location services are off. Enable GPS in settings.',
    LocationStatus.denied => 'Location permission denied. You can try again.',
    LocationStatus.deniedForever =>
      'Location permission is blocked. Allow it in app settings.',
    LocationStatus.error =>
      'Could not retrieve your location. Check GPS and try again.',
  };
}

class LocationService {
  Future<Position> freshPosition() async {
    if (!await servicesEnabled()) {
      throw const LocationFailure(
        'Location services are off. Enable GPS in device settings.',
      );
    }
    var permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(
        'Location access is blocked. Allow it in app settings, then try again.',
      );
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      throw const LocationFailure(
        'Location permission is required to signal a taxi. Tap again to allow it.',
      );
    }
    try {
      return await currentPosition();
    } catch (_) {
      throw const LocationFailure(
        'Could not get a fresh GPS fix. Check your location settings and try again.',
      );
    }
  }

  Future<bool> servicesEnabled() => Geolocator.isLocationServiceEnabled();
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();
  Future<Position> currentPosition() => Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 20),
    ),
  );
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}

class LocationFailure implements Exception {
  const LocationFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

final locationServiceProvider = Provider((ref) => LocationService());
final locationProvider =
    NotifierProvider.autoDispose<LocationController, LocationState>(
      LocationController.new,
    );

class LocationController extends Notifier<LocationState> {
  bool _alive = true;
  @override
  LocationState build() {
    _alive = true;
    ref.onDispose(() => _alive = false);
    return const LocationState(LocationStatus.idle);
  }

  Future<void> refresh() async {
    if (state.status == LocationStatus.loading) return;
    final service = ref.read(locationServiceProvider);
    state = const LocationState(LocationStatus.loading);
    void emit(LocationState value) {
      if (_alive) state = value;
    }

    try {
      if (!await service.servicesEnabled()) {
        emit(const LocationState(LocationStatus.servicesDisabled));
        return;
      }
      var permission = await service.checkPermission();
      if (!_alive) return;
      if (permission == LocationPermission.denied) {
        permission = await service.requestPermission();
      }
      if (!_alive) return;
      if (permission == LocationPermission.deniedForever) {
        emit(const LocationState(LocationStatus.deniedForever));
        return;
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        emit(const LocationState(LocationStatus.denied));
        return;
      }
      final position = await service.currentPosition();
      emit(LocationState(LocationStatus.ready, position: position));
    } catch (_) {
      emit(const LocationState(LocationStatus.error));
    }
  }
}
