import 'package:flutter/material.dart';
import '../../app/theme/okae_theme.dart';
import '../../shared/widgets/kit.dart';

class PassengerScreen extends StatelessWidget {
  const PassengerScreen({super.key});
  @override
  Widget build(BuildContext context) => ModeScaffold(
    mode: 'PASSENGER',
    children: [
      const Tag('A HAND UP, DIGITISED'),
      const SizedBox(height: 20),
      Text(
        'Be seen.\nGet moving.',
        style: Theme.of(context).textTheme.displayMedium,
      ),
      const SizedBox(height: 16),
      const Text(
        'Let nearby taxi drivers know you’re waiting.',
        style: TextStyle(fontSize: 18, height: 1.5),
      ),
      const SizedBox(height: 28),
      const LocationPanel(),
      const SizedBox(height: 28),
      Center(
        child: Container(
          width: 230,
          height: 230,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: orange.withValues(alpha: .22), width: 2),
          ),
          child: FilledButton(
            onPressed: null,
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              disabledBackgroundColor: ink,
              disabledForegroundColor: Colors.white,
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.waving_hand_rounded, size: 42),
                SizedBox(height: 14),
                Text(
                  'SIGNAL TAXI',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
                ),
                SizedBox(height: 8),
                Text(
                  'Coming in Batch 2',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 24),
      const Center(child: Tag('PREVIEW • NO SIGNAL IS ACTIVE')),
      const SizedBox(height: 28),
      const InfoPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A simple signal. Your choice.',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
            ),
            SizedBox(height: 12),
            Text(
              'When enabled, your signal will be visible to participating taxi drivers within 500 metres for 5 minutes. You’ll be able to cancel it at any time.',
              style: TextStyle(height: 1.6),
            ),
            SizedBox(height: 12),
            Text(
              'A signal lets drivers know you’re waiting. It does not book a taxi or guarantee a pickup.',
              style: TextStyle(height: 1.5),
            ),
          ],
        ),
      ),
    ],
  );
}
