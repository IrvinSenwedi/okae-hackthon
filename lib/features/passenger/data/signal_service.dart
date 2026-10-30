import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/location/location_controller.dart';
import '../../../core/services/passenger_auth.dart';

class PassengerSignal {
  const PassengerSignal({required this.id, required this.expiresAt});
  final String id;
  final DateTime expiresAt;
}

class SignalSnapshot {
  const SignalSnapshot({
    required this.serverNow,
    required this.signal,
    this.roundTrip = Duration.zero,
  });
  final DateTime serverNow;
  final PassengerSignal? signal;
  final Duration roundTrip;
  Duration get remaining {
    final difference = signal?.expiresAt.difference(serverNow) ?? Duration.zero;
    // Subtract the full request time conservatively; never extend server expiry.
    final micros = (difference - roundTrip).inMicroseconds.clamp(
      0,
      const Duration(minutes: 5).inMicroseconds,
    );
    return Duration(microseconds: micros);
  }

  factory SignalSnapshot.fromJson(
    Map<String, dynamic> json,
    Duration roundTrip,
  ) {
    final row = json['signal'] as Map<String, dynamic>?;
    return SignalSnapshot(
      serverNow: DateTime.parse(json['server_now'] as String),
      roundTrip: roundTrip,
      signal: row == null
          ? null
          : PassengerSignal(
              id: row['id'] as String,
              expiresAt: DateTime.parse(row['expires_at'] as String),
            ),
    );
  }
}

abstract class SignalService {
  Stream<String> get authProblems => const Stream.empty();
  Future<String> passengerId();
  Future<SignalSnapshot> getCurrentSignal();
  Future<SignalSnapshot> createSignal(
    String requestId, {
    void Function()? onActivating,
  });
  Future<SignalSnapshot> cancelSignal(String signalId);
}

class SupabaseSignalService implements SignalService {
  @override
  Stream<String> get authProblems => auth.problems;
  SupabaseSignalService(this.client, this.auth, this.location);
  final SupabaseClient client;
  final PassengerAuth auth;
  final LocationService location;
  @override
  Future<String> passengerId() => auth.ensureUser();
  Future<SignalSnapshot> _rpc(
    String function, [
    Map<String, dynamic>? params,
  ]) async {
    await auth.ensureUser();
    final timer = Stopwatch()..start();
    final result = await client
        .rpc(function, params: params)
        .timeout(const Duration(seconds: 15));
    timer.stop();
    return SignalSnapshot.fromJson(
      Map<String, dynamic>.from(result as Map),
      timer.elapsed,
    );
  }

  @override
  Future<SignalSnapshot> getCurrentSignal() => _rpc('get_current_signal');
  @override
  Future<SignalSnapshot> createSignal(
    String requestId, {
    void Function()? onActivating,
  }) async {
    final owner = await auth.ensureUser();
    final position = await location.freshPosition();
    if (await auth.ensureUser() != owner) {
      throw const SignalFailure(
        'Passenger session changed. Check your signal status.',
      );
    }
    onActivating?.call();
    return _rpc('create_passenger_signal', {
      'p_request_id': requestId,
      'p_latitude': position.latitude,
      'p_longitude': position.longitude,
      'p_accuracy_m': position.accuracy.isFinite && position.accuracy >= 0
          ? position.accuracy
          : null,
    });
  }

  @override
  Future<SignalSnapshot> cancelSignal(String signalId) =>
      _rpc('cancel_passenger_signal', {'p_signal_id': signalId});
}

class SignalIntent {
  const SignalIntent(this.kind, this.id);
  final String kind, id;
}

abstract class SignalIntentStore {
  Future<SignalIntent?> read(String owner);
  Future<void> write(String owner, SignalIntent intent);
  Future<void> clear(String owner);
}

class PreferencesSignalIntentStore implements SignalIntentStore {
  final _preferences = SharedPreferencesAsync();
  String _key(String owner) => 'okae.signal.intent.$owner';
  @override
  Future<SignalIntent?> read(String owner) async {
    final value = await _preferences.getString(_key(owner));
    if (value == null) return null;
    final json = jsonDecode(value) as Map<String, dynamic>;
    return SignalIntent(json['kind'] as String, json['id'] as String);
  }

  @override
  Future<void> write(String owner, SignalIntent intent) =>
      _preferences.setString(
        _key(owner),
        jsonEncode({'kind': intent.kind, 'id': intent.id}),
      );
  @override
  Future<void> clear(String owner) => _preferences.remove(_key(owner));
}

final signalIntentStoreProvider = Provider<SignalIntentStore>(
  (ref) => PreferencesSignalIntentStore(),
);
final signalServiceProvider = Provider<SignalService>(
  (ref) => SupabaseSignalService(
    Supabase.instance.client,
    ref.watch(passengerAuthProvider),
    ref.watch(locationServiceProvider),
  ),
);
