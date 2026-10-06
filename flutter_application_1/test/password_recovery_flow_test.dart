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

import 'auth_controller_test.dart' show MemoryStorage;

const user = {
  'id': '11111111-1111-4111-8111-111111111111',
  'aud': 'authenticated',
  'email': 'a@example.invalid',
  'created_at': '2026-01-01T00:00:00Z',
  'app_metadata': <String, dynamic>{},
  'user_metadata': <String, dynamic>{},
};
final session = jsonEncode({
  'access_token': 'token-a',
  'refresh_token': 'refresh-a',
  'token_type': 'bearer',
  'expires_in': 3600,
  'user': user,
});

/// The link Supabase emails: the PKCE code lands before the hash route.
final resetLink = Uri.parse(
  'https://app.example/?code=one-time-code#/reset-password',
);

/// Real Supabase SDK (PKCE flow, the SDK default) against a scripted server.
class RecoveryServer {
  final requests = <http.Request>[];
  http.Response Function(http.Request) updateUser = (_) =>
      http.Response(jsonEncode(user), 200);
  late final client = SupabaseClient(
    'https://example.supabase.co',
    'sb_publishable_test',
    authOptions: AuthClientOptions(
      autoRefreshToken: false,
      pkceAsyncStorage: MemoryStorage(),
    ),
    httpClient: MockClient((r) async {
      requests.add(r);
      final path = r.url.path;
      if (path.endsWith('/recover')) return http.Response('{}', 200);
      if (path.endsWith('/logout')) return http.Response('', 204);
      if (path.endsWith('/user') && r.method == 'PUT') return updateUser(r);
      if (path.endsWith('/token')) return http.Response(session, 200);
      return http.Response('{}', 404);
    }),
  );
  Iterable<http.Request> get passwordWrites =>
      requests.where((r) => r.url.path.endsWith('/user') && r.method == 'PUT');
  Iterable<http.Request> get codeExchanges =>
      requests.where((r) => r.url.queryParameters['grant_type'] == 'pkce');
}

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(FigmaDesign.load);

  test('A normal sign-in never grants recovery or a password change', () async {
    final server = RecoveryServer();
    final auth = AuthController(server.client);
    await auth.login('a@example.invalid', 'password');
    await settle();
    expect(auth.signedIn, true);
    expect(auth.recovering, false);
    await expectLater(
      auth.updatePassword('another-password'),
      throwsA(isA<AuthException>()),
    );
    expect(server.passwordWrites, isEmpty);
    auth.dispose();
    await server.client.dispose();
  });

  test(
    'A valid reset link enables recovery and the password changes once',
    () async {
      final server = RecoveryServer();
      final auth = AuthController(server.client);
      await auth.requestPasswordReset('a@example.invalid');
      expect(
        auth.recovering,
        false,
        reason: 'requesting an email grants nothing',
      );
      await server.client.auth.getSessionFromUrl(resetLink);
      await settle();
      expect(auth.recovering, true);
      await auth.updatePassword('new-password-123');
      expect(auth.recovering, false);
      expect(server.passwordWrites, hasLength(1));
      expect(
        jsonDecode(server.passwordWrites.single.body)['password'],
        'new-password-123',
      );
      // Reusing the same link: the one-time verifier is gone, nothing is sent.
      Object? reuse;
      try {
        await server.client.auth.getSessionFromUrl(resetLink);
      } catch (error) {
        reuse = error;
      }
      await settle();
      expect(reuse, isA<AuthException>());
      expect(AuthController.linkMessage(reuse!), isNotNull);
      expect(server.codeExchanges, hasLength(1));
      expect(auth.recovering, false);
      await expectLater(
        auth.updatePassword('third-password'),
        throwsA(anything),
      );
      expect(server.passwordWrites, hasLength(1));
      auth.dispose();
      await server.client.dispose();
    },
  );

  test(
    'An expired recovery session fails safely with a useful message',
    () async {
      final server = RecoveryServer()
        ..updateUser = (_) => http.Response(
          jsonEncode({
            'error_code': 'session_not_found',
            'msg': 'Session not found',
          }),
          403,
        );
      final auth = AuthController(server.client);
      await auth.requestPasswordReset('a@example.invalid');
      await server.client.auth.getSessionFromUrl(resetLink);
      await settle();
      Object? failure;
      try {
        await auth.updatePassword('new-password-123');
      } catch (error) {
        failure = error;
      }
      expect(failure, isA<AuthException>());
      expect(
        AuthController.message(failure!),
        'Linkul de resetare a expirat. Cere un link nou.',
      );
      auth.dispose();
      await server.client.dispose();
    },
  );

  test(
    'A link opened without its verifier (other browser) grants nothing',
    () async {
      final server = RecoveryServer();
      final auth = AuthController(server.client);
      Object? failure;
      try {
        await server.client.auth.getSessionFromUrl(resetLink);
      } catch (error) {
        failure = error;
      }
      await settle();
      expect(AuthController.linkMessage(failure!), isNotNull);
      expect(auth.recovering, false);
      expect(auth.signedIn, false);
      auth.dispose();
      await server.client.dispose();
    },
  );

  group('App', () {
    // Clients created inside a widget test's fake-async zone never finish
    // disposing, so the app tests share one created in setUp.
    late RecoveryServer server;
    setUp(() => server = RecoveryServer()..client);
    tearDown(() => server.client.dispose());

    Future<void> openResetRoute(WidgetTester tester) async {
      final context = tester.element(find.byType(Scaffold).first);
      Navigator.pushNamed(context, '/reset-password');
      await tester.pumpAndSettle();
    }

    ApiService emptyApi(AuthController auth) => ApiService(
      baseUrl: 'https://api.example.invalid',
      accessToken: auth.accessToken,
      client: MockClient((_) async => http.Response('{"items":[]}', 200)),
    );

    testWidgets('Opening /reset-password signed out shows sign-in, not reset', (
      tester,
    ) async {
      final auth = AuthController(server.client);
      final api = emptyApi(auth);
      await tester.pumpWidget(WastelessApp(auth: auth, api: api));
      await tester.pumpAndSettle();
      await openResetRoute(tester);
      expect(find.byKey(const ValueKey('new-password')), findsNothing);
      expect(find.byKey(const ValueKey('field-5:148')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      api.close();
      auth.dispose();
    });

    testWidgets('Opening /reset-password while signed in grants nothing', (
      tester,
    ) async {
      final auth = AuthController(server.client);
      await auth.login('a@example.invalid', 'password');
      final api = emptyApi(auth);
      await tester.pumpWidget(WastelessApp(auth: auth, api: api));
      await tester.pumpAndSettle();
      await openResetRoute(tester);
      expect(find.byKey(const ValueKey('new-password')), findsNothing);
      expect(auth.recovering, false);
      await tester.pumpWidget(const SizedBox());
      api.close();
      auth.dispose();
    });

    testWidgets('Recovery event shows the reset form; saving leaves recovery', (
      tester,
    ) async {
      final auth = AuthController(server.client);
      final api = emptyApi(auth);
      await auth.requestPasswordReset('a@example.invalid');
      await server.client.auth.getSessionFromUrl(resetLink);
      await tester.pumpWidget(WastelessApp(auth: auth, api: api));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('new-password')), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('new-password')),
        'new-password-123',
      );
      await tester.enterText(
        find.byKey(const ValueKey('confirm-password')),
        'new-password-123',
      );
      await tester.tap(find.byKey(const ValueKey('password-submit')));
      await tester.pumpAndSettle();
      expect(server.passwordWrites, hasLength(1));
      expect(auth.recovering, false);
      expect(find.byKey(const ValueKey('new-password')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      api.close();
      auth.dispose();
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
