import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/auth/auth_controller.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/widgets/figma_layout.dart';

const user = {
  'id': '11111111-1111-4111-8111-111111111111',
  'aud': 'authenticated',
  'email': 'a@example.invalid',
  'created_at': '2026-01-01T00:00:00Z',
  'app_metadata': <String, dynamic>{},
  'user_metadata': <String, dynamic>{},
};

/// JWT-shaped access token: the SDK reads expiry from its `exp` claim.
String jwt(int expiresIn) {
  String part(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + expiresIn;
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({'sub': user['id'], 'exp': exp})}.sig';
}

/// A real Supabase client against a scripted Auth server.
class AuthServer {
  AuthServer({this.expiresIn = 3600});
  final int expiresIn;
  late final token = jwt(expiresIn);
  int logouts = 0;
  http.Response Function(http.Request)? refresh;
  late final client = SupabaseClient(
    'https://example.supabase.co',
    'sb_publishable_test',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((r) async {
      if (r.url.path.endsWith('/logout')) {
        logouts++;
        return http.Response('', 204);
      }
      if (r.url.queryParameters['grant_type'] == 'refresh_token') {
        return refresh!(r);
      }
      return http.Response(
        jsonEncode({
          'access_token': token,
          'refresh_token': 'refresh-a',
          'token_type': 'bearer',
          'expires_in': expiresIn,
          'user': user,
        }),
        200,
      );
    }),
  );
}

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(FigmaDesign.load);

  test('Concurrent 401s sign out exactly once', () async {
    final server = AuthServer();
    final auth = AuthController(server.client);
    await auth.login('a@example.invalid', 'password');
    var notified = 0;
    auth.addListener(() => notified++);
    final api = ApiService(
      baseUrl: 'https://api.example.invalid',
      accessToken: auth.accessToken,
      onSessionRejected: auth.sessionRejected,
      client: MockClient((_) async => http.Response('{"detail":"x"}', 401)),
    );
    final results = await Future.wait([
      for (var i = 0; i < 5; i++)
        api
            .request('GET', '/api/cart')
            .then<Object?>((v) => v, onError: (Object e) => e),
    ]);
    await settle();
    expect(results, everyElement(isA<ApiException>()));
    expect(auth.signedIn, false);
    expect(server.logouts, 1);
    expect(auth.notice, 'Sesiunea a expirat. Autentifică-te din nou.');
    expect(notified, greaterThan(0));
    // Once signed out, further calls never reach the API or Auth again.
    await expectLater(
      api.request('GET', '/api/cart'),
      throwsA(isA<ApiException>()),
    );
    expect(server.logouts, 1);
    api.close();
    auth.dispose();
    await server.client.dispose();
  });

  test(
    'A late 401 for an older token cannot sign out the current session',
    () async {
      final server = AuthServer();
      final auth = AuthController(server.client);
      await auth.login('a@example.invalid', 'password');
      await auth.sessionRejected('token-from-previous-session');
      expect(auth.signedIn, true);
      expect(server.logouts, 0);
      expect(auth.notice, isNull);
      auth.dispose();
      await server.client.dispose();
    },
  );

  test(
    'A refresh token Supabase rejects ends the session with a notice',
    () async {
      final server = AuthServer(expiresIn: 0)
        ..refresh = (_) => http.Response(
          jsonEncode({
            'error_code': 'refresh_token_not_found',
            'msg': 'Invalid Refresh Token: Refresh Token Not Found',
          }),
          400,
        );
      final auth = AuthController(server.client);
      await auth.login('a@example.invalid', 'password');
      await expectLater(
        auth.accessToken(),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
      );
      await settle();
      expect(auth.signedIn, false);
      expect(auth.notice, 'Sesiunea a expirat. Autentifică-te din nou.');
      auth.dispose();
      await server.client.dispose();
    },
  );

  test('Being offline while refreshing keeps the user signed in', () async {
    final server = AuthServer(expiresIn: 0)
      ..refresh = (_) => throw http.ClientException('offline');
    final auth = AuthController(server.client);
    await auth.login('a@example.invalid', 'password');
    await expectLater(
      auth.accessToken(),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', isNull)),
    );
    await settle();
    expect(auth.signedIn, true);
    expect(server.logouts, 0);
    expect(auth.notice, isNull);
    auth.dispose();
    await server.client.dispose();
  });

  group('App', () {
    // See password_recovery_flow_test: clients must outlive fake async.
    late AuthServer server;
    setUp(() => server = AuthServer()..client);
    tearDown(() => server.client.dispose());

    testWidgets('Expired session in the catalogue returns to sign-in once', (
      tester,
    ) async {
      final auth = AuthController(server.client);
      await auth.login('a@example.invalid', 'password');
      var apiCalls = 0;
      final api = ApiService(
        baseUrl: 'https://api.example.invalid',
        accessToken: auth.accessToken,
        onSessionRejected: auth.sessionRejected,
        client: MockClient((_) async {
          apiCalls++;
          return http.Response('{"detail":"Sesiunea a expirat."}', 401);
        }),
      );
      await tester.pumpWidget(WastelessApp(auth: auth, api: api));
      await tester.pumpAndSettle();
      // Favorites and products both failed, but the app signed out only once.
      expect(server.logouts, 1);
      expect(auth.signedIn, false);
      expect(find.byKey(const ValueKey('field-5:148')), findsOneWidget);
      expect(find.byKey(const ValueKey('auth-notice')), findsOneWidget);
      expect(
        find.text('Sesiunea a expirat. Autentifică-te din nou.'),
        findsOneWidget,
      );
      final calls = apiCalls;
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(
        apiCalls,
        calls,
        reason: 'sign-in screen must not keep calling the API',
      );
      expect(server.logouts, 1);
      await tester.pumpWidget(const SizedBox());
      api.close();
      auth.dispose();
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  test('Signing in again clears the expired-session notice', () async {
    final server = AuthServer();
    final auth = AuthController(server.client);
    await auth.login('a@example.invalid', 'password');
    await auth.sessionRejected(server.token);
    expect(auth.notice, isNotNull);
    await auth.login('a@example.invalid', 'password');
    expect(auth.signedIn, true);
    expect(auth.notice, isNull);
    auth.dispose();
    await server.client.dispose();
  });
}
