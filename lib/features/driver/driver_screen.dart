import 'package:flutter/material.dart';
import '../../shared/widgets/kit.dart';
import 'driver_map.dart';

class DriverScreen extends StatelessWidget {
  const DriverScreen({super.key});
  @override
  Widget build(BuildContext context) => ModeScaffold(
    mode: 'DRIVER',
    children: [
      Text(
        'Eyes on the road.',
        style: Theme.of(context).textTheme.headlineLarge,
      ),
      const SizedBox(height: 12),
      const Text(
        'Park safely before using Okae. Location is refreshed only when you ask.',
      ),
      const SizedBox(height: 20),
      const InfoPanel(
        child: Row(
          children: [
            Icon(Icons.radio_button_off),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Offline',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text('Availability opens in Batch 3'),
                ],
              ),
            ),
            Switch(value: false, onChanged: null),
          ],
        ),
      ),
      const SizedBox(height: 16),
      const SizedBox(height: 340, child: DriverMap()),
      const SizedBox(height: 16),
      const LocationPanel(),
      const SizedBox(height: 24),
      const Text(
        'Nearby passenger signals',
        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      const InfoPanel(
        child: Column(
          children: [
            Icon(Icons.sensors_off, size: 32),
            SizedBox(height: 12),
            Text(
              'No signals available',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8),
            Text(
              'Live discovery is not connected in this preview. No passenger signals are being fetched.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ],
  );
}
