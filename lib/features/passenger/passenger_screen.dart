import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/okae_theme.dart';
import '../../shared/widgets/kit.dart';
import 'application/signal_controller.dart';

class PassengerScreen extends ConsumerWidget {
  const PassengerScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(signalControllerProvider);
    final controller = ref.read(signalControllerProvider.notifier);
    final confirmedActive =
        state.phase == SignalPhase.active &&
        !state.checking &&
        !state.uncertain;
    final label = switch (state.phase) {
      SignalPhase.gettingLocation => 'GETTING LOCATION',
      SignalPhase.activating => 'ACTIVATING',
      SignalPhase.active =>
        state.checking ? 'CHECKING STATUS' : 'SIGNAL ACTIVE',
      SignalPhase.cancelling => 'CANCELLING',
      SignalPhase.cancelled => 'SIGNAL CANCELLED',
      SignalPhase.expired => 'SIGNAL EXPIRED',
      SignalPhase.error => 'CHECK SIGNAL STATUS',
      SignalPhase.idle =>
        state.checking ? 'CHECKING STATUS' : 'READY WHEN YOU ARE',
    };
    return ModeScaffold(
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
          'Let nearby taxi drivers know you are waiting.',
          style: TextStyle(fontSize: 18, height: 1.5),
        ),
        const SizedBox(height: 28),
        if (state.signal == null && !state.busy) ...[
          const LocationPanel(),
          const SizedBox(height: 28),
        ],
        Center(
          child: Container(
            width: 250,
            height: 250,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: orange.withValues(alpha: .25),
                width: 2,
              ),
            ),
            child: FilledButton(
              onPressed: state.canActivate ? controller.activate : null,
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                disabledBackgroundColor: confirmedActive ? orange : ink,
                disabledForegroundColor: Colors.white,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (state.busy)
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  else
                    Icon(
                      confirmedActive
                          ? Icons.sensors
                          : Icons.waving_hand_rounded,
                      size: 40,
                    ),
                  const SizedBox(height: 12),
                  Text(
                    confirmedActive
                        ? 'SIGNAL ACTIVE'
                        : state.phase == SignalPhase.gettingLocation
                        ? 'LOCATING...'
                        : state.phase == SignalPhase.activating
                        ? 'ACTIVATING...'
                        : state.checking
                        ? 'CHECKING...'
                        : 'SIGNAL TAXI',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.signal != null
                        ? state.checking || state.uncertain
                              ? '--:--'
                              : state.countdown
                        : '500 m · 5 minutes',
                    style: TextStyle(
                      fontSize: state.signal != null ? 30 : 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(child: Semantics(liveRegion: true, child: Tag(label))),
        if (state.signal != null) ...[
          const SizedBox(height: 16),
          Text(
            confirmedActive
                ? 'Your waiting location is stored for your signal. Nearby participating drivers may see it when driver discovery is enabled. Driver delivery is not active yet.'
                : 'Checking your last confirmed signal. Its server-defined expiry has not changed.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: state.busy ? null : controller.cancel,
              icon: const Icon(Icons.close),
              label: const Text('CANCEL SIGNAL'),
            ),
          ),
        ],
        if (state.message != null) ...[
          const SizedBox(height: 20),
          InfoPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(liveRegion: true, child: Text(state.message!)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: state.busy ? null : controller.restore,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Check status'),
                ),
              ],
            ),
          ),
        ],
        if (state.phase == SignalPhase.cancelled ||
            state.phase == SignalPhase.expired) ...[
          const SizedBox(height: 16),
          Text(
            state.phase == SignalPhase.cancelled
                ? 'Your signal was cancelled. You can signal again when you are ready.'
                : 'Your five-minute signal has ended. You can signal again.',
          ),
        ],
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
                'A signal lasts up to 5 minutes. Cancel it at any time. Your location is captured once when you activate, with no background tracking.',
                style: TextStyle(height: 1.6),
              ),
              SizedBox(height: 12),
              Text(
                'This does not book a taxi or guarantee a pickup. Secure discovery within 500 metres is coming in Batch 3.',
                style: TextStyle(height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
