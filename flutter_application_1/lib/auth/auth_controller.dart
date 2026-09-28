import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/api_service.dart';

class AuthController extends ChangeNotifier {
  AuthController(this.client) {
    _subscription = client.auth.onAuthStateChange.listen(
      (_) => notifyListeners(),
      onError: (Object error) {
        notifyListeners();
      },
    );
  }
  final SupabaseClient client;
  late final StreamSubscription<AuthState> _subscription;
  User? get user => client.auth.currentUser;
  bool get signedIn => client.auth.currentSession != null;

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
