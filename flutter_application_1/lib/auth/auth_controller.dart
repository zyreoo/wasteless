import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/api_service.dart';

class AuthController extends ChangeNotifier {
  AuthController(
    this.client, {
    this.recoveryRedirectUrl = '',
    bool startInRecovery = false,
  }) : _recovering = startInRecovery {
    _subscription = client.auth.onAuthStateChange.listen(
      (state) {
        if (state.event == AuthChangeEvent.passwordRecovery) {
          _recovering = true;
        }
        notifyListeners();
      },
      onError: (Object error) {
        notifyListeners();
      },
    );
  }
  final SupabaseClient client;
  final String recoveryRedirectUrl;
  bool _recovering;
  late final StreamSubscription<AuthState> _subscription;
  User? get user => client.auth.currentUser;
  bool get signedIn => client.auth.currentSession != null;
  bool get recovering => _recovering;

  Future<String?> accessToken() async {
    var session = client.auth.currentSession;
    if (session == null) return null;
    if (session.isExpired) {
      try {
        session = (await client.auth.refreshSession()).session;
      } on AuthException {
        throw const ApiException(
          'Sesiunea nu poate fi reînnoită. Autentifică-te din nou.',
          status: 401,
        );
      }
    }
    return session?.accessToken;
  }

  Future<void> login(String email, String password) async {
    final result = await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    if (result.session == null) {
      throw const AuthException('Autentificarea nu a fost finalizată.');
    }
  }

  Future<bool> register(String email, String password, String name) async {
    final result = await client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': name.trim()},
    );
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
      throw const AuthException('Sesiunea de recuperare nu este validă.');
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

  Future<void> logout() => client.auth.signOut(scope: SignOutScope.local);

  static String message(Object error) {
    if (error is ApiException) return error.message;
    if (error is AuthException) {
      return switch (error.code) {
        'invalid_credentials' => 'Emailul sau parola nu sunt corecte.',
        'email_not_confirmed' =>
          'Confirmă adresa de email înainte de autentificare.',
        'weak_password' => 'Alege o parolă mai puternică.',
        'over_email_send_rate_limit' || 'over_request_rate_limit' =>
          'Prea multe încercări. Revino în câteva momente.',
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
