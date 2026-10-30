import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppConfig {
  const AppConfig({
    this.mapboxToken = '',
    this.supabaseUrl = '',
    this.supabaseKey = '',
  });
  const AppConfig.environment()
    : mapboxToken = const String.fromEnvironment('ACCESS_TOKEN'),
      supabaseUrl = const String.fromEnvironment('SUPABASE_URL'),
      supabaseKey = const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  final String mapboxToken, supabaseUrl, supabaseKey;
  bool get hasMapbox => mapboxToken.trim().startsWith('pk.');
  bool get hasBackend => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
  bool get validBackendUrl {
    final uri = Uri.tryParse(supabaseUrl);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }

  static const signalRadiusMetres = 500;
  static const signalDuration = Duration(minutes: 5);
}

final configProvider = Provider<AppConfig>(
  (ref) => const AppConfig.environment(),
);
