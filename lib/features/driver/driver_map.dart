import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../core/config/app_config.dart';
import '../../core/location/location_controller.dart';
import '../../shared/widgets/kit.dart';

class DriverMap extends ConsumerStatefulWidget {
  const DriverMap({super.key});
  @override
  ConsumerState<DriverMap> createState() => _DriverMapState();
}

class _DriverMapState extends ConsumerState<DriverMap>
    with WidgetsBindingObserver {
  bool _foreground = true;
  String? _error;
  int _attempt = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted) {
      setState(() => _foreground = state == AppLifecycleState.resumed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(configProvider);
    final position = ref.watch(locationProvider).position;
    final supported =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!config.hasMapbox) {
      return const InfoPanel(
        child: Center(
          child: Text(
            'Map unavailable\nConfigure a Mapbox public access token (ACCESS_TOKEN).',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (!supported) {
      return const InfoPanel(
        child: Center(
          child: Text('The map is available on Android, iOS and web.'),
        ),
      );
    }
    if (!_foreground) {
      return const InfoPanel(
        child: Center(
          child: Text('Map paused while Okae is in the background.'),
        ),
      );
    }
    if (position == null) {
      return const InfoPanel(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_searching, size: 42),
              SizedBox(height: 16),
              Text(
                'Your map starts where you are.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8),
              Text(
                'Use your location below to load the map.\nNo location is being shared.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    if (_error != null) {
      return InfoPanel(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.map_outlined, size: 36),
              const SizedBox(height: 12),
              const Text(
                'Map could not load. Check your connection and Mapbox token.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => setState(() {
                  _error = null;
                  _attempt++;
                }),
                child: const Text('Retry map'),
              ),
            ],
          ),
        ),
      );
    }
    // A static GPS indicator avoids enabling continuous tracking while offline.
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          MapWidget(
            key: ValueKey(
              '$_attempt:${position.latitude}:${position.longitude}',
            ),
            viewport: CameraViewportState(
              center: Point(
                coordinates: Position(position.longitude, position.latitude),
              ),
              zoom: 15,
            ),
            onMapLoadErrorListener: (_) {
              if (mounted) setState(() => _error = 'load');
            },
            onMapCreated: (map) async {
              try {
                final manager = await map.annotations
                    .createCircleAnnotationManager();
                await manager.create(
                  CircleAnnotationOptions(
                    geometry: Point(
                      coordinates: Position(
                        position.longitude,
                        position.latitude,
                      ),
                    ),
                    circleRadius: 9,
                    circleColor: 0xFF2563EB,
                    circleStrokeColor: 0xFFFFFFFF,
                    circleStrokeWidth: 3,
                  ),
                );
              } catch (_) {
                if (mounted) setState(() => _error = 'indicator');
              }
            },
          ),
          const Positioned(
            top: 12,
            left: 12,
            child: Tag('YOUR LAST GPS REFRESH'),
          ),
        ],
      ),
    );
  }
}
