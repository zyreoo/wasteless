import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/auth/auth_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const user = {
    'id': '11111111-1111-4111-8111-111111111111',
    'aud': 'authenticated',
    'email': 'a@example.invalid',
    'created_at': '2026-01-01T00:00:00Z',
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
  };
  SupabaseClient client(MockClient http) => SupabaseClient(
    'https://example.supabase.co',
    'sb_publishable_test',
    httpClient: http,
    authOptions: AuthClientOptions(autoRefreshToken: false, pkceAsyncStorage: MemoryStorage()),
  );

  test('Login establishes real SDK session, logout clears it', () async {
    final c = client(
      MockClient((r) async {
        if (r.url.path.endsWith('/logout')) return http.Response('', 204);
        expect(jsonDecode(r.body)['email'], 'a@example.invalid');
        return http.Response(
          jsonEncode({
            'access_token': 'access-token',
            'token_type': 'bearer',
            'refresh_token': 'refresh-token',
            'expires_in': 3600,
            'user': user,
          }),
          200,
        );
      }),
    );
    final auth = AuthController(c);
    expect(auth.signedIn, false);
    await auth.login(' a@example.invalid ', 'password');
    expect(auth.signedIn, true);
    expect(await auth.accessToken(), 'access-token');
    await auth.logout();
    expect(auth.signedIn, false);
    expect(await auth.accessToken(), isNull);
    auth.dispose();
    await c.dispose();
  });

  test('Confirmation-required registration does not fake a session', () async {
    final c = client(
      MockClient((_) async => http.Response(jsonEncode(user), 200)),
    );
    final auth = AuthController(c);
    expect(await auth.register('a@example.invalid', 'password', 'Ana'), false);
    expect(auth.signedIn, false);
    auth.dispose();
    await c.dispose();
  });

  test('Invalid login leaves user signed out', () async {
    final c = client(
      MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error_code': 'invalid_credentials',
            'msg': 'Invalid credentials',
          }),
          400,
        ),
      ),
    );
    final auth = AuthController(c);
    await expectLater(
      auth.login('a@example.invalid', 'wrong'),
      throwsA(isA<AuthException>()),
    );
    expect(auth.signedIn, false);
    auth.dispose();
    await c.dispose();
  });
}

class MemoryStorage extends GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async { values[key] = value; }
  @override
  Future<void> removeItem({required String key}) async { values.remove(key); }
}
