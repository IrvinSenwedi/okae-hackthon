import 'package:flutter/material.dart';
import '../../app/theme/okae_theme.dart';
import '../../shared/widgets/kit.dart';
import '../passenger/passenger_screen.dart';
import '../driver/driver_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Wrap(
                  spacing: 20,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'OKAE',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                      ),
                    ),
                    Tag('BATCH 01 / PREVIEW'),
                  ],
                ),
                const SizedBox(height: 44),
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: ink,
                    borderRadius: BorderRadius.circular(36),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                      ),
                      Container(
                        width: 108,
                        height: 108,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white38),
                        ),
                      ),
                      const Icon(
                        Icons.waving_hand_rounded,
                        size: 66,
                        color: Color(0xFFFFB789),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Your next taxi.\nStarts with you.',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Making passengers visible to nearby taxis.',
                  style: TextStyle(fontSize: 19, height: 1.4),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PassengerScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.waving_hand_outlined),
                    label: const Text("I'm a Passenger"),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const DriverScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.airport_shuttle_outlined),
                    label: const Text("I'm a Driver"),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'A digital hand up for South African minibus taxis.\nChoose your mode to explore the foundation.',
                  style: TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
