import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okae/app/app.dart';
import 'package:okae/core/config/app_config.dart';
import 'package:okae/features/driver/driver_map.dart';

void main() {
  testWidgets('starts and opens passenger with signalling disabled', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: OkaeApp()));
    expect(
      find.text('Making passengers visible to nearby taxis.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text("I'm a Passenger"));
    await tester.tap(find.text("I'm a Passenger"));
    await tester.pumpAndSettle();
    expect(find.text('PASSENGER'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'SIGNAL TAXI'),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('PREVIEW • NO SIGNAL IS ACTIVE'), findsOneWidget);
  });
  testWidgets('driver stays offline with missing map config and no signals', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: OkaeApp()));
    await tester.ensureVisible(find.text("I'm a Driver"));
    await tester.tap(find.text("I'm a Driver"));
    await tester.pumpAndSettle();
    expect(find.byType(DriverMap), findsOneWidget);
    expect(
      find.textContaining('Configure a Mapbox public access token'),
      findsOneWidget,
    );
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    expect(find.text('No signals available'), findsOneWidget);
  });
  testWidgets('configured map waits for actual GPS', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          configProvider.overrideWithValue(
            const AppConfig(mapboxToken: 'pk.test'),
          ),
        ],
        child: const MaterialApp(
          home: SizedBox(height: 340, child: DriverMap()),
        ),
      ),
    );
    expect(find.text('Your map starts where you are.'), findsOneWidget);
  });
  testWidgets('small screen navigation has no overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProviderScope(child: OkaeApp()));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text("I'm a Driver"));
    await tester.tap(find.text("I'm a Driver"));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
