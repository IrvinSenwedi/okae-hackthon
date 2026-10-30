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
      'Your location stays on this device in this preview.',
    LocationStatus.loading => 'Finding your current location…',
    LocationStatus.ready =>
      'Current location available. Nothing is being shared.',
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
