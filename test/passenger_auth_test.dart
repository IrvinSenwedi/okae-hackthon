import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:okae/core/services/passenger_auth.dart';

class FakeAuthGateway implements AuthGateway {
  AuthIdentity? current;
  int signIns = 0, refreshes = 0;
  bool refreshFails = false, signInFails = false;
  Completer<AuthIdentity?>? pending;
  final events = StreamController<String?>.broadcast();
  @override
  AuthIdentity? get session => current;
  @override
  Stream<String?> get identityChanges => events.stream;
  @override
  Future<AuthIdentity?> signInAnonymously() async {
    signIns++;
    if (signInFails) throw Exception('network');
    return current = pending == null
        ? const AuthIdentity('passenger-a')
        : await pending!.future;
  }

  @override
  Future<AuthIdentity?> refreshSession() async {
    refreshes++;
    if (refreshFails) throw Exception('offline');
    return current = const AuthIdentity('passenger-a');
  }
}

void main() {
  late FakeAuthGateway gateway;
  late PassengerAuth auth;
  setUp(() {
    gateway = FakeAuthGateway();
    auth = PassengerAuth(gateway);
  });
  tearDown(() {
    auth.dispose();
    gateway.events.close();
  });
  test('anonymous authentication succeeds and reuses saved identity', () async {
    expect(await auth.ensureUser(), 'passenger-a');
    expect(await auth.ensureUser(), 'passenger-a');
    expect(gateway.signIns, 1);
  });
  test('existing session is reused without creating account', () async {
    gateway.current = const AuthIdentity('saved');
    expect(await auth.ensureUser(), 'saved');
    expect(gateway.signIns, 0);
  });
  test('concurrent requests share a single authentication', () async {
    gateway.pending = Completer();
    final a = auth.ensureUser();
    final b = auth.ensureUser();
    gateway.pending!.complete(const AuthIdentity('passenger-a'));
    expect(await a, await b);
    expect(gateway.signIns, 1);
  });
  test('expired access token refreshes existing identity', () async {
    gateway.current = const AuthIdentity('passenger-a', expired: true);
    expect(await auth.ensureUser(), 'passenger-a');
    expect(gateway.refreshes, 1);
    expect(gateway.signIns, 0);
  });
  test('refresh failure never silently creates new account', () async {
    gateway.current = const AuthIdentity('passenger-a', expired: true);
    gateway.refreshFails = true;
    await expectLater(auth.ensureUser(), throwsException);
    expect(gateway.signIns, 0);
  });
  test('sign-in network failure is retryable', () async {
    gateway.signInFails = true;
    await expectLater(auth.ensureUser(), throwsException);
    gateway.signInFails = false;
    expect(await auth.ensureUser(), 'passenger-a');
  });
  test('refresh stream errors are handled and surfaced', () async {
    final notice = auth.problems.first;
    gateway.events.addError(Exception('offline'));
    expect(await notice, contains('Session refresh failed'));
  });
  test('lost identity blocks a replacement anonymous account', () async {
    await auth.ensureUser();
    gateway.current = null;
    gateway.events.add(null);
    await Future<void>.delayed(Duration.zero);
    await expectLater(auth.ensureUser(), throwsA(isA<SignalFailure>()));
    expect(gateway.signIns, 1);
  });
}
