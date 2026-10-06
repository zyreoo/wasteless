import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/api_service.dart';

class AuthController extends ChangeNotifier {
  AuthController(this.client, {this.recoveryRedirectUrl = ''}) {
    // Recovery mode is granted only by the SDK's passwordRecovery event, which
    // it emits after exchanging a valid reset link. The URL alone proves nothing.
    _subscription = client.auth.onAuthStateChange.listen(
      (state) {
        if (state.event == AuthChangeEvent.passwordRecovery) {
          _recovering = true;
          _notice = null;
        } else if (state.event == AuthChangeEvent.signedOut) {
          _recovering = false;
        }
        notifyListeners();
      },
      onError: (Object error) {
        _notice = linkMessage(error) ?? _notice;
        notifyListeners();
      },
    );
  }
  final SupabaseClient client;
  final String recoveryRedirectUrl;
  bool _recovering = false;
  String? _notice;
  Future<void>? _expiring;
  late final StreamSubscription<AuthState> _subscription;
  User? get user => client.auth.currentUser;
  bool get signedIn => client.auth.currentSession != null;
  bool get recovering => _recovering;

  /// One-off message for the sign-in screen (expired session, dead reset link).
  String? get notice => _notice;

  Future<String?> accessToken() async {
    var session = client.auth.currentSession;
    if (session == null) return null;
    if (session.isExpired) {
      final stale = session.accessToken;
      try {
        session = (await client.auth.refreshSession()).session;
      } on AuthRetryableFetchException {
        // Offline is not a dead session; keep the user signed in.
        throw const ApiException(
          'Nu ne putem conecta. Verifică conexiunea la internet.',
        );
      } on AuthException {
        // The SDK may already have dropped the session; still explain why.
        _notice = 'Sesiunea a expirat. Autentifică-te din nou.';
        await sessionRejected(stale);
        notifyListeners();
        throw const ApiException(
          'Sesiunea a expirat. Autentifică-te din nou.',
          status: 401,
        );
      }
    }
    return session?.accessToken;
  }

  /// Signs out locally when the API refused [token]. Ignores tokens from an
  /// older session and collapses concurrent 401s into a single sign-out.
  Future<void> sessionRejected(String token) async {
    final pending = _expiring;
    if (pending != null) return pending;
    final current = client.auth.currentSession;
    if (current == null || current.accessToken != token) return;
    final done = Completer<void>();
    _expiring = done.future;
    try {
      _recovering = false;
      _notice = 'Sesiunea a expirat. Autentifică-te din nou.';
      await client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      // The SDK removes the local session before its network call.
    } finally {
      _expiring = null;
      done.complete();
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    final result = await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    if (result.session == null) {
      throw const AuthException('Autentificarea nu a fost finalizată.');
    }
    _notice = null;
  }

  Future<bool> register(String email, String password, String name) async {
    final result = await client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': name.trim()},
    );
    if (result.session != null) _notice = null;
    return result.session != null;
  }

  Future<void> requestPasswordReset(String email) async {
    await client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: recoveryRedirectUrl.isEmpty ? null : recoveryRedirectUrl,
    );
  }

  Future<void> updatePassword(String password) async {
    if (client.auth.currentSession == null || !_recovering) {
      throw const AuthException(
        'Recovery session missing',
        code: 'recovery_session_missing',
      );
    }
    await client.auth.updateUser(UserAttributes(password: password));
    _recovering = false;
    notifyListeners();
  }

  Future<void> cancelRecovery() async {
    _recovering = false;
    await client.auth.signOut(scope: SignOutScope.local);
    notifyListeners();
  }

  Future<void> logout() async {
    _notice = null;
    await client.auth.signOut(scope: SignOutScope.local);
  }

  /// Message for a reset/confirmation link the SDK could not exchange.
  static String? linkMessage(Object error) {
    if (error is AuthPKCEGrantCodeExchangeError) return _linkInvalid;
    if (error is! AuthException) return null;
    const codes = {
      'otp_expired',
      'flow_state_not_found',
      'flow_state_expired',
      'bad_code_verifier',
      'access_denied',
    };
    if (codes.contains(error.code) ||
        error.message.contains('Code verifier could not be found')) {
      return _linkInvalid;
    }
    return null;
  }

  static const _linkInvalid =
      'Linkul nu mai este valid. Cere un link nou și deschide-l în același browser.';

  static String message(Object error) {
    if (error is ApiException) return error.message;
    if (error is AuthRetryableFetchException) {
      return 'Nu ne putem conecta. Verifică conexiunea și încearcă din nou.';
    }
    if (error is AuthException) {
      return switch (error.code) {
        'invalid_credentials' => 'Emailul sau parola nu sunt corecte.',
        'email_not_confirmed' =>
          'Confirmă adresa de email înainte de autentificare.',
        'weak_password' => 'Alege o parolă mai puternică.',
        'same_password' => 'Alege o parolă diferită de cea actuală.',
        'over_email_send_rate_limit' || 'over_request_rate_limit' =>
          'Prea multe încercări. Revino în câteva momente.',
        'recovery_session_missing' ||
        'session_not_found' ||
        'session_expired' ||
        'refresh_token_not_found' ||
        'refresh_token_already_used' ||
        'reauthentication_needed' =>
          'Linkul de resetare a expirat. Cere un link nou.',
        _ => 'Autentificarea nu a reușit. Verifică datele și încearcă din nou.',
      };
    }
    return 'Nu ne putem conecta. Verifică conexiunea și încearcă din nou.';
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
