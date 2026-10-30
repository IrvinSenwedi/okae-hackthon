import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/location/location_controller.dart';
import '../../../core/services/backend.dart';
import '../../../core/services/passenger_auth.dart';
import '../data/signal_service.dart';

enum SignalPhase {
  idle,
  gettingLocation,
  activating,
  active,
  cancelling,
  cancelled,
  expired,
  error,
}

class SignalState {
  const SignalState({
    this.phase = SignalPhase.idle,
    this.signal,
    this.remaining = Duration.zero,
    this.message,
    this.checking = false,
    this.uncertain = false,
    this.ready = false,
  });
  final SignalPhase phase;
  final PassengerSignal? signal;
  final Duration remaining;
  final String? message;
  final bool checking, uncertain, ready;
  bool get busy =>
      checking ||
      phase == SignalPhase.gettingLocation ||
      phase == SignalPhase.activating ||
      phase == SignalPhase.cancelling;
  bool get canActivate => ready && !busy && !uncertain && signal == null;
  String get countdown {
    final seconds = (remaining.inMilliseconds / 1000).ceil().clamp(0, 300);
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

class SignalClock {
  final Stopwatch _watch = Stopwatch()..start();
  Duration get elapsed => _watch.elapsed;
}

final signalClockProvider = Provider((ref) => SignalClock());
final signalControllerProvider =
    NotifierProvider<SignalController, SignalState>(SignalController.new);

class SignalController extends Notifier<SignalState>
    with WidgetsBindingObserver {
  bool _disposed = false, _busy = false, _suspended = false;
  SignalService? _service;
  late SignalIntentStore _store;
  late SignalClock _clock;
  String? _owner;
  SignalIntent? _intent;
  Timer? _timer;
  Duration _deadline = Duration.zero;
  StreamSubscription<String>? _authProblems;
  @override
  SignalState build() {
    _disposed = false;
    _clock = ref.read(signalClockProvider);
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
      _authProblems?.cancel();
      WidgetsBinding.instance.removeObserver(this);
    });
    if (ref.watch(backendProvider) != BackendStatus.initialized) {
      return const SignalState(
        phase: SignalPhase.error,
        message:
            'Passenger signalling is not configured. Add Supabase configuration and restart the app.',
      );
    }
    _store = ref.read(signalIntentStoreProvider);
    _service = ref.read(signalServiceProvider);
    _authProblems = _service!.authProblems.listen((message) {
      if (!_disposed) {
        _set(
          SignalState(
            phase: SignalPhase.error,
            signal: state.signal,
            remaining: state.remaining,
            message: message,
            ready: true,
            uncertain: true,
          ),
        );
      }
    });
    Future.microtask(restore);
    return const SignalState(checking: true);
  }

  void _set(SignalState value) {
    if (!_disposed) state = value;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _suspended = state != AppLifecycleState.resumed;
    if (_suspended) {
      _timer?.cancel();
    } else {
      _tick();
      unawaited(restore());
    }
  }

  String _message(Object error) {
    if (error is LocationFailure) return error.message;
    if (error is SignalFailure) return error.message;
    if (error is AuthException) {
      return 'Could not authenticate. Check your connection and enable anonymous sign-ins in Supabase, then check status.';
    }
    if (error is PostgrestException &&
        (error.code == 'PGRST202' || error.code == '42P01')) {
      return 'Passenger signalling is not deployed yet. Apply the Batch 2 database migration, then check status.';
    }
    return 'Could not confirm the signal with the server. Check your connection, then check status before trying again.';
  }

  Future<void> _loadOwner() async {
    final owner = await _service!.passengerId();
    if (_owner != null && owner != _owner) {
      throw const SignalFailure(
        'Passenger session changed. Restart the app to restore the current session.',
      );
    }
    _owner = owner;
    _intent = await _store.read(owner);
  }

  Future<void> _clearIntent() async {
    if (_owner != null) await _store.clear(_owner!);
    _intent = null;
  }

  Future<void> _apply(
    SignalSnapshot snapshot, {
    SignalPhase empty = SignalPhase.idle,
  }) async {
    if (_disposed) return;
    final signal = snapshot.signal;
    if (signal == null || snapshot.remaining <= Duration.zero) {
      _timer?.cancel();
      if (_intent?.kind == 'cancel') await _clearIntent();
      _set(
        SignalState(
          phase: signal == null ? empty : SignalPhase.expired,
          ready: true,
        ),
      );
      return;
    }
    if (_intent?.kind == 'create') await _clearIntent();
    _deadline = _clock.elapsed + snapshot.remaining;
    _set(
      SignalState(
        phase: SignalPhase.active,
        signal: signal,
        remaining: snapshot.remaining,
        ready: true,
      ),
    );
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (!_suspended && !_disposed) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  void _tick() {
    if (_disposed || state.signal == null) return;
    final remaining = _deadline - _clock.elapsed;
    if (remaining <= Duration.zero) {
      _timer?.cancel();
      _set(const SignalState(phase: SignalPhase.expired, ready: true));
    } else {
      _set(
        SignalState(
          phase: state.phase,
          signal: state.signal,
          remaining: remaining,
          message: state.message,
          checking: state.checking,
          uncertain: state.uncertain,
          ready: state.ready,
        ),
      );
    }
  }

  Future<void> restore() async {
    if (_disposed || _busy || _service == null) return;
    _busy = true;
    final previous = state;
    _set(
      SignalState(
        phase: previous.phase,
        signal: previous.signal,
        remaining: previous.remaining,
        checking: true,
        ready: false,
      ),
    );
    try {
      await _loadOwner();
      final snapshot = await _service!.getCurrentSignal();
      await _apply(
        snapshot,
        empty: _intent?.kind == 'cancel'
            ? SignalPhase.cancelled
            : previous.signal != null || previous.phase == SignalPhase.expired
            ? SignalPhase.expired
            : SignalPhase.idle,
      );
      if (!_disposed && _intent?.kind == 'cancel' && state.signal != null) {
        _set(
          SignalState(
            phase: SignalPhase.error,
            signal: state.signal,
            remaining: state.remaining,
            ready: true,
            message:
                'Cancellation was not confirmed. Retry cancellation while connected.',
          ),
        );
      }
    } catch (error) {
      _set(
        SignalState(
          phase: SignalPhase.error,
          signal: previous.signal,
          remaining: previous.remaining,
          message: _message(error),
          ready: true,
          uncertain: true,
        ),
      );
    } finally {
      _busy = false;
      if (!_disposed && state.signal != null) {
        _tick();
        _startTimer();
      }
    }
  }

  Future<void> activate() async {
    if (_disposed || _busy || !state.canActivate || _service == null) return;
    _busy = true;
    _set(const SignalState(phase: SignalPhase.gettingLocation));
    var sent = false;
    try {
      await _loadOwner();
      // Reconcile before every mutation, including retries after timeouts.
      final current = await _service!.getCurrentSignal();
      if (current.signal != null && current.remaining > Duration.zero) {
        await _apply(current);
        return;
      }
      if (_suspended) {
        throw const SignalFailure(
          'Return to Okae before requesting your location.',
        );
      }
      final id = _intent?.kind == 'create' ? _intent!.id : const Uuid().v4();
      _intent = SignalIntent('create', id);
      await _store.write(_owner!, _intent!);
      final result = await _service!.createSignal(
        id,
        onActivating: () {
          if (_suspended || _disposed) {
            throw const SignalFailure(
              'Keep Okae open while activating your signal.',
            );
          }
          sent = true;
          _set(const SignalState(phase: SignalPhase.activating));
        },
      );
      await _clearIntent();
      await _apply(result, empty: SignalPhase.expired);
    } catch (error) {
      if (sent) {
        await _reconcileFailure(error);
      } else {
        // GPS/auth errors happened before a write, so activation is safely retryable.
        _set(
          SignalState(
            phase: SignalPhase.error,
            message: _message(error),
            ready: true,
            uncertain: error is! LocationFailure && error is! SignalFailure,
          ),
        );
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> cancel() async {
    if (_disposed || _busy || state.signal == null || _service == null) return;
    _busy = true;
    final signal = state.signal!;
    _set(
      SignalState(
        phase: SignalPhase.cancelling,
        signal: signal,
        remaining: state.remaining,
      ),
    );
    try {
      await _loadOwner();
      _intent = SignalIntent('cancel', signal.id);
      await _store.write(_owner!, _intent!);
      final result = await _service!.cancelSignal(signal.id);
      if (result.signal != null) {
        throw const SignalFailure(
          'Cancellation was not confirmed. Check status and retry.',
        );
      }
      await _clearIntent();
      await _apply(result, empty: SignalPhase.cancelled);
    } catch (error) {
      await _reconcileFailure(error, cancelling: true);
    } finally {
      _busy = false;
    }
  }

  Future<void> _reconcileFailure(
    Object original, {
    bool cancelling = false,
  }) async {
    try {
      final result = await _service!.getCurrentSignal();
      await _apply(
        result,
        empty: cancelling ? SignalPhase.cancelled : SignalPhase.idle,
      );
      if (cancelling && result.signal == null) return;
      if (!cancelling && result.signal != null) return;
      _set(
        SignalState(
          phase: SignalPhase.error,
          signal: state.signal,
          remaining: state.remaining,
          ready: true,
          message: cancelling
              ? 'Your signal is still active. Retry cancellation.'
              : _message(original),
        ),
      );
    } catch (_) {
      _set(
        SignalState(
          phase: SignalPhase.error,
          signal: state.signal,
          remaining: state.remaining,
          ready: true,
          uncertain: true,
          message: _message(original),
        ),
      );
    }
  }
}
