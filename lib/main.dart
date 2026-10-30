import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/services/backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const config = AppConfig.environment();
  if (config.hasMapbox) MapboxOptions.setAccessToken(config.mapboxToken);
  final backend = await initializeBackend(config);
  runApp(
    ProviderScope(
      overrides: [backendProvider.overrideWithValue(backend)],
      child: const OkaeApp(),
    ),
  );
}
