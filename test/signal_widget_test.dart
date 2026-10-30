import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okae/app/app.dart';
import 'package:okae/core/services/backend.dart';
import 'package:okae/features/passenger/application/signal_controller.dart';
import 'package:okae/features/passenger/data/signal_service.dart';
import 'signal_controller_test.dart' show FakeClock, FakeSignals, MemoryIntents;

void main() {
  testWidgets('passenger activates, navigates away/back and cancels', (
    tester,
  ) async {
    final clock = FakeClock();
    final service = FakeSignals(clock);
    final container = ProviderContainer(
      overrides: [
        backendProvider.overrideWithValue(BackendStatus.initialized),
        signalServiceProvider.overrideWithValue(service),
        signalIntentStoreProvider.overrideWithValue(MemoryIntents()),
        signalClockProvider.overrideWithValue(clock),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const OkaeApp()),
    );
    await tester.ensureVisible(find.text("I'm a Passenger"));
    await tester.tap(find.text("I'm a Passenger"));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'SIGNAL TAXI'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.ensureVisible(find.text('SIGNAL TAXI'));
    await tester.tap(find.text('SIGNAL TAXI'));
    await tester.pumpAndSettle();
    expect(find.text('05:00'), findsOneWidget);
    expect(find.text('CANCEL SIGNAL'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text("I'm a Passenger"));
    await tester.tap(find.text("I'm a Passenger"));
    await tester.pumpAndSettle();
    expect(service.creates, 1);
    await tester.ensureVisible(find.text('CANCEL SIGNAL'));
    await tester.tap(find.text('CANCEL SIGNAL'));
    await tester.pumpAndSettle();
    expect(find.text('SIGNAL CANCELLED'), findsOneWidget);
    expect(service.cancels, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}
