import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

enum BackendStatus {
  missingConfiguration,
  invalidConfiguration,
  initialized,
  initializationFailed,
}

final backendProvider = Provider<BackendStatus>(
  (ref) => BackendStatus.missingConfiguration,
);
Future<BackendStatus> initializeBackend(AppConfig config) async {
  if (!config.hasBackend) return BackendStatus.missingConfiguration;
  if (!config.validBackendUrl) return BackendStatus.invalidConfiguration;
  try {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseKey,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
    );
    return BackendStatus.initialized;
  } catch (_) {
    return BackendStatus.initializationFailed;
  }
}

enum ConnectionStatus {
  missingConfiguration,
  invalidConfiguration,
  reachable,
  failed,
}

Future<ConnectionStatus> checkBackendConnection(
  AppConfig config,
  http.Client client,
) async {
  if (!config.hasBackend) return ConnectionStatus.missingConfiguration;
  if (!config.validBackendUrl) return ConnectionStatus.invalidConfiguration;
  try {
    final response = await client
        .get(
          Uri.parse('${config.supabaseUrl}/auth/v1/health'),
          headers: {'apikey': config.supabaseKey},
        )
        .timeout(const Duration(seconds: 10));
    return response.statusCode == 200
        ? ConnectionStatus.reachable
        : ConnectionStatus.failed;
  } catch (_) {
    return ConnectionStatus.failed;
  }
}

final connectionProvider = FutureProvider.autoDispose<ConnectionStatus>((
  ref,
) async {
  final client = http.Client();
  ref.onDispose(client.close);
  return checkBackendConnection(ref.watch(configProvider), client);
});
