import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'backend.dart';

class AuthIdentity {
  const AuthIdentity(this.userId, {this.expired = false});
  final String userId;
  final bool expired;
}

abstract class AuthGateway {
  AuthIdentity? get session;
  Stream<String?> get identityChanges;
  Future<AuthIdentity?> signInAnonymously();
  Future<AuthIdentity?> refreshSession();
}

class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this.client);
  final SupabaseClient client;
  AuthIdentity? _identity(Session? session) => session == null
      ? null
      : AuthIdentity(session.user.id, expired: session.isExpired);
  @override
  AuthIdentity? get session => _identity(client.auth.currentSession);
  @override
  Stream<String?> get identityChanges =>
      client.auth.onAuthStateChange.map((event) => event.session?.user.id);
  @override
  Future<AuthIdentity?> signInAnonymously() async =>
      _identity((await client.auth.signInAnonymously()).session);
  @override
  Future<AuthIdentity?> refreshSession() async =>
      _identity((await client.auth.refreshSession()).session);
}

class PassengerAuth {
  PassengerAuth(this.gateway) {
    _previousUser = gateway.session?.userId;
    _subscription = gateway.identityChanges.listen(
      (user) {
        if (_previousUser != null && user != _previousUser) {
          _identityLost = true;
          _problems.add(
            'Your passenger session changed. Check signal status before continuing.',
          );
        }
        if (user != null) _previousUser = user;
      },
      onError: (Object error, StackTrace stack) {
        // Refresh network failures are stream errors, not uncaught app errors.
        _problems.add(
          'Session refresh failed. Reconnect and check signal status.',
        );
      },
    );
  }
  final AuthGateway gateway;
  final _problems = StreamController<String>.broadcast();
  Stream<String> get problems => _problems.stream;
  late final StreamSubscription<String?> _subscription;
  String? _previousUser;
  bool _identityLost = false;
  Future<String>? _pending;
  Future<String> ensureUser() =>
      _pending ??= _ensure().whenComplete(() => _pending = null);
  Future<String> _ensure() async {
    if (_identityLost) {
      throw const SignalFailure(
        'Your saved passenger session is unavailable. Reconnect and restart the app; an active signal still expires on the server.',
      );
    }
    var session = gateway.session;
    // A refresh failure must never fall through into creating a different account.
    if (session != null && session.expired) {
      final savedUser = session.userId;
      session = await gateway.refreshSession();
      if (session == null || session.expired) {
        throw const SignalFailure(
          'Could not refresh your session. Reconnect and try again.',
        );
      }
      if (session.userId != savedUser) {
        throw const SignalFailure(
          'Session identity changed during refresh. Restart and check signal status.',
        );
      }
    } else {
      session ??= await gateway.signInAnonymously();
    }
    if (session == null || session.expired) {
      throw const SignalFailure(
        'Could not authenticate. Check your connection and anonymous sign-in setup.',
      );
    }
    _previousUser = session.userId;
    return session.userId;
  }

  void dispose() {
    _subscription.cancel();
    _problems.close();
  }
}

class SignalFailure implements Exception {
  const SignalFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

final passengerAuthProvider = Provider<PassengerAuth>((ref) {
  if (ref.watch(backendProvider) != BackendStatus.initialized) {
    throw const SignalFailure(
      'Passenger signalling is not configured. Check Supabase setup and restart.',
    );
  }
  final auth = PassengerAuth(SupabaseAuthGateway(Supabase.instance.client));
  ref.onDispose(auth.dispose);
  return auth;
});
