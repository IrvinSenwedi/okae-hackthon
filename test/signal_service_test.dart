import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:okae/core/services/passenger_auth.dart';
import 'package:okae/core/location/location_controller.dart';
import 'package:okae/features/passenger/data/signal_service.dart';
import 'location_test.dart' show FakeLocation;
import 'passenger_auth_test.dart' show FakeAuthGateway;

void main() {
  late SupabaseClient client;
  late PassengerAuth auth;
  late FakeAuthGateway gateway;
  late FakeLocation location;
  late SupabaseSignalService service;
  late List<http.Request> requests;
  bool fail = false;
  setUp(() {
    requests = [];
    fail = false;
    gateway = FakeAuthGateway()..current = const AuthIdentity('passenger-a');
    auth = PassengerAuth(gateway);
    location = FakeLocation();
    client = SupabaseClient(
      'https://example.supabase.co',
      'public-test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (fail) {
          return http.Response(
            '{"message":"unavailable"}',
            503,
            request: request,
          );
        }
        final cancelled = request.url.path.endsWith('cancel_passenger_signal');
        return http.Response(
          jsonEncode({
            'server_now': '2040-01-01T00:00:00Z',
            'signal': cancelled
                ? null
                : {'id': 'server-id', 'expires_at': '2040-01-01T00:05:00Z'},
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    service = SupabaseSignalService(client, auth, location);
  });
  tearDown(() async {
    auth.dispose();
    await gateway.events.close();
    await client.dispose();
  });
  test(
    'creation retrieves fresh GPS and sends only allowed RPC inputs',
    () async {
      var activating = false;
      final snapshot = await service.createSignal(
        'request-id',
        onActivating: () => activating = true,
      );
      expect(activating, true);
      expect(location.calls, 1);
      expect(requests.single.url.path, '/rest/v1/rpc/create_passenger_signal');
      expect(jsonDecode(requests.single.body), {
        'p_request_id': 'request-id',
        'p_latitude': -26.2,
        'p_longitude': 28.0,
        'p_accuracy_m': 5.0,
      });
      expect(snapshot.signal!.id, 'server-id');
      expect(snapshot.signal!.expiresAt, DateTime.utc(2040, 1, 1, 0, 5));
      expect(gateway.signIns, 0);
    },
  );
  test('cancel uses scoped RPC, never arbitrary table updates', () async {
    final snapshot = await service.cancelSignal('server-id');
    expect(snapshot.signal, isNull);
    expect(requests.single.url.path, '/rest/v1/rpc/cancel_passenger_signal');
    expect(jsonDecode(requests.single.body), {'p_signal_id': 'server-id'});
  });
  test('restore reads authoritative signal without GPS', () async {
    final snapshot = await service.getCurrentSignal();
    expect(snapshot.signal!.id, 'server-id');
    expect(location.calls, 0);
    expect(requests.single.url.path, '/rest/v1/rpc/get_current_signal');
  });
  test('denied GPS prevents any database request', () async {
    location.permission = LocationPermission.denied;
    await expectLater(
      service.createSignal('request-id'),
      throwsA(isA<LocationFailure>()),
    );
    expect(requests, isEmpty);
    expect(location.calls, 0);
  });
  test('backend rejection never returns confirmed activation', () async {
    fail = true;
    await expectLater(
      service.createSignal('request-id'),
      throwsA(isA<PostgrestException>()),
    );
  });
}
