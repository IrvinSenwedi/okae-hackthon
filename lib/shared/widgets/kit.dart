import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/okae_theme.dart';
import '../../core/location/location_controller.dart';

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: ink.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    ),
  );
}

class InfoPanel extends StatelessWidget {
  const InfoPanel({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: ink.withValues(alpha: .09)),
    ),
    child: child,
  );
}

class LocationPanel extends ConsumerWidget {
  const LocationPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(locationProvider);
    final loading = location.status == LocationStatus.loading;
    return InfoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.my_location, size: 20),
              SizedBox(width: 10),
              Text(
                'Your location',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(location.message),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: loading
                    ? null
                    : () => ref.read(locationProvider.notifier).refresh(),
                icon: Icon(loading ? Icons.hourglass_top : Icons.refresh),
                label: Text(
                  loading
                      ? 'Locating…'
                      : location.position == null
                      ? 'Use my location'
                      : 'Refresh location',
                ),
              ),
              if (location.status == LocationStatus.deniedForever ||
                  location.status == LocationStatus.servicesDisabled)
                TextButton(
                  onPressed: () async {
                    final service = ref.read(locationServiceProvider);
                    final opened =
                        location.status == LocationStatus.deniedForever
                        ? await service.openAppSettings()
                        : await service.openLocationSettings();
                    if (!opened && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please open your device settings manually.',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Open settings'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class ModeScaffold extends StatelessWidget {
  const ModeScaffold({required this.mode, required this.children, super.key});
  final String mode;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'OKAE',
        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 3),
      ),
      actions: [
        Padding(padding: const EdgeInsets.only(right: 16), child: Tag(mode)),
      ],
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ),
    ),
  );
}
