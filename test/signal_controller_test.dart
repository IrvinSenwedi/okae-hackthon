import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okae/core/location/location_controller.dart';
import 'package:okae/core/services/backend.dart';
import 'package:okae/features/passenger/application/signal_controller.dart';
import 'package:okae/features/passenger/data/signal_service.dart';

class MemoryIntents implements SignalIntentStore {
  SignalIntent? intent;
  @override
  Future<SignalIntent?> read(String owner) async => intent;
  @override
  Future<void> write(String owner, SignalIntent value) async {
    intent = value;
  }

  @override
  Future<void> clear(String owner) async {
    intent = null;
  }
}

class FakeClock extends SignalClock {
  Duration time = Duration.zero;
  @override
  Duration get elapsed => time;
}

class FakeSignals extends SignalService {
  FakeSignals(this.clock);
  final FakeClock clock;
  final base = DateTime.utc(2040);
  PassengerSignal? stored;
  int creates = 0, cancels = 0, reads = 0;
  bool failRead = false,
      denied = false,
      timeoutCreate = false,
      timeoutCancel = false,
      failCancel = false;
  Completer<void>? gate;
  String? lastRequest;
  DateTime get now => base.add(clock.elapsed);
  SignalSnapshot snapshot() => SignalSnapshot(
    serverNow: now,
    signal: stored != null && stored!.expiresAt.isAfter(now) ? stored : null,
  );
  @override
  Future<String> passengerId() async => 'owner';
  @override
  Future<SignalSnapshot> getCurrentSignal() async {
    reads++;
    if (failRead) throw Exception('offline');
    return snapshot();
  }

  @override
  Future<SignalSnapshot> createSignal(
    String requestId, {
    void Function()? onActivating,
  }) async {
    if (denied) throw const LocationFailure('Location permission is required.');
    onActivating?.call();
    creates++;
    lastRequest = requestId;
    if (gate != null) await gate!.future;
    stored ??= PassengerSignal(
      id: requestId,
      expiresAt: now.add(const Duration(minutes: 5)),
    );
    if (timeoutCreate) throw TimeoutException('reply lost');
    return snapshot();
  }

  @override
  Future<SignalSnapshot> cancelSignal(String signalId) async {
    cancels++;
    if (failCancel) throw Exception('offline');
    stored = null;
    if (timeoutCancel) throw TimeoutException('reply lost');
    return snapshot();
  }
}

void main() {
  late FakeClock clock;
  late FakeSignals service;
  late MemoryIntents store;
  late ProviderContainer container;
  late SignalController controller;
  ProviderContainer makeContainer() => ProviderContainer(
    overrides: [
      backendProvider.overrideWithValue(BackendStatus.initialized),
      signalServiceProvider.overrideWithValue(service),
      signalIntentStoreProvider.overrideWithValue(store),
      signalClockProvider.overrideWithValue(clock),
    ],
  );
  Future<void> start(WidgetTester tester) async {
    clock = FakeClock();
    service = FakeSignals(clock);
    store = MemoryIntents();
    container = makeContainer();
    controller = container.read(signalControllerProvider.notifier);
    addTearDown(() => container.dispose());
    await tester.pump();
  }

  testWidgets('creates confirmed signal and cancels it', (tester) async {
    await start(tester);
    expect(container.read(signalControllerProvider).canActivate, true);
    await controller.activate();
    expect(container.read(signalControllerProvider).phase, SignalPhase.active);
    expect(container.read(signalControllerProvider).countdown, '05:00');
    await controller.cancel();
    expect(
      container.read(signalControllerProvider).phase,
      SignalPhase.cancelled,
    );
    expect(container.read(signalControllerProvider).canActivate, true);
    expect(store.intent, isNull);
  });
  testWidgets('rapid taps do not duplicate activation', (tester) async {
    await start(tester);
    service.gate = Completer();
    final first = controller.activate();
    await tester.pump();
    await controller.activate();
    expect(service.creates, 1);
    container.dispose();
    service.gate!.complete();
    await first;
    await controller.activate();
    expect(service.creates, 1);
  });
  testWidgets('fresh location denial never creates a signal', (tester) async {
    await start(tester);
    service.denied = true;
    await controller.activate();
    expect(service.creates, 0);
    expect(container.read(signalControllerProvider).phase, SignalPhase.error);
    expect(container.read(signalControllerProvider).canActivate, true);
  });
  testWidgets(
    'five-minute countdown uses monotonic server offset, not device clock',
    (tester) async {
      await start(tester);
      await controller.activate();
      clock.time = const Duration(seconds: 61);
      await tester.pump(const Duration(seconds: 1));
      expect(container.read(signalControllerProvider).countdown, '03:59');
      clock.time = const Duration(minutes: 5);
      await tester.pump(const Duration(seconds: 1));
      expect(
        container.read(signalControllerProvider).phase,
        SignalPhase.expired,
      );
      expect(container.read(signalControllerProvider).canActivate, true);
    },
  );
  testWidgets('lost creation reply reconciles confirmed server signal', (
    tester,
  ) async {
    await start(tester);
    service.timeoutCreate = true;
    await controller.activate();
    expect(container.read(signalControllerProvider).phase, SignalPhase.active);
    expect(service.creates, 1);
    container.dispose();
  });
  testWidgets('unknown backend state blocks repeated submissions', (
    tester,
  ) async {
    await start(tester);
    service.failRead = true;
    await controller.activate();
    expect(service.creates, 0);
    expect(container.read(signalControllerProvider).canActivate, false);
    service.failRead = false;
    await controller.restore();
    expect(container.read(signalControllerProvider).canActivate, true);
  });
  testWidgets('lost cancellation reply reconciles cancelled state', (
    tester,
  ) async {
    await start(tester);
    await controller.activate();
    service.timeoutCancel = true;
    await controller.cancel();
    expect(
      container.read(signalControllerProvider).phase,
      SignalPhase.cancelled,
    );
    expect(service.stored, isNull);
  });
  testWidgets('failed cancellation retains signal and permits cancel retry', (
    tester,
  ) async {
    await start(tester);
    await controller.activate();
    service.failCancel = true;
    await controller.cancel();
    expect(container.read(signalControllerProvider).phase, SignalPhase.error);
    expect(container.read(signalControllerProvider).signal, isNotNull);
    expect(container.read(signalControllerProvider).canActivate, false);
    service.failCancel = false;
    await controller.cancel();
    expect(
      container.read(signalControllerProvider).phase,
      SignalPhase.cancelled,
    );
  });
  testWidgets('restart restores server signal without extending expiry', (
    tester,
  ) async {
    await start(tester);
    await controller.activate();
    final expiry = service.stored!.expiresAt;
    container.dispose();
    clock.time = const Duration(minutes: 2);
    container = makeContainer();
    controller = container.read(signalControllerProvider.notifier);
    await tester.pump();
    expect(container.read(signalControllerProvider).countdown, '03:00');
    expect(container.read(signalControllerProvider).signal!.expiresAt, expiry);
    expect(service.creates, 1);
    container.dispose();
  });
  testWidgets('background/resume checks server expiry', (tester) async {
    await start(tester);
    await controller.activate();
    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    clock.time = const Duration(minutes: 6);
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(container.read(signalControllerProvider).phase, SignalPhase.expired);
  });
  testWidgets('durable uncertain request id survives controller restart', (
    tester,
  ) async {
    await start(tester);
    store.intent = const SignalIntent('create', 'saved-request');
    await controller.restore();
    await controller.activate();
    expect(service.lastRequest, 'saved-request');
    container.dispose();
  });
  testWidgets('disposal during request does not write provider state', (
    tester,
  ) async {
    await start(tester);
    service.gate = Completer();
    final pending = controller.activate();
    await tester.pump();
    container.dispose();
    service.gate!.complete();
    await pending;
    expect(tester.takeException(), isNull);
  });
  test('network latency only reduces remaining time', () {
    final snapshot = SignalSnapshot(
      serverNow: DateTime.utc(2040),
      signal: PassengerSignal(
        id: 'id',
        expiresAt: DateTime.utc(2040).add(const Duration(minutes: 5)),
      ),
      roundTrip: const Duration(seconds: 3),
    );
    expect(snapshot.remaining, const Duration(seconds: 297));
  });
}
