import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/auth/auth_controller.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/widgets/figma_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(FigmaDesign.load);
  SupabaseClient client() => SupabaseClient(
    'https://example.supabase.co',
    'sb_publishable_test',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((r) async {
      if (r.url.path.endsWith('logout')) return http.Response('', 204);
      return http.Response(
        jsonEncode({
          'access_token': 'token',
          'refresh_token': 'refresh',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': '11111111-1111-4111-8111-111111111111',
            'aud': 'authenticated',
            'email': 'a@example.invalid',
            'created_at': '2026-01-01T00:00:00Z',
            'app_metadata': {},
            'user_metadata': {},
          },
        }),
        200,
      );
    }),
  );
  late SupabaseClient c;
  setUp(() {
    c = client();
  });
  tearDown(() async {
    await c.dispose();
  });
  testWidgets('Unauthenticated navigation cannot reach protected cart', (
    tester,
  ) async {
    final auth = AuthController(c);
    int calls = 0;
    final api = ApiService(
      baseUrl: 'https://api.example.invalid',
      accessToken: auth.accessToken,
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    await tester.pumpWidget(WastelessApp(auth: auth, api: api));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    Navigator.pushNamed(context, '/cart');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('field-5:148')), findsOneWidget);
    expect(calls, 0);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
    api.close();
  }, timeout: const Timeout(Duration(seconds: 30)));
  testWidgets('Logout removes account data and protected navigation stack', (
    tester,
  ) async {
    final auth = AuthController(c);
    await auth.login('a@example.invalid', 'password');
    final api = ApiService(
      baseUrl: 'https://api.example.invalid',
      accessToken: auth.accessToken,
      client: MockClient(
        (r) async => http.Response(
          jsonEncode({
            'items': r.url.path.endsWith('favorites')
                ? []
                : [
                    {
                      'id': 7,
                      'name': 'Account A product',
                      'price': 1,
                      'stock': 2,
                    },
                  ],
          }),
          200,
        ),
      ),
    );
    await tester.pumpWidget(WastelessApp(auth: auth, api: api));
    await tester.pumpAndSettle();
    expect(find.text('Account A product'), findsOneWidget);
    await auth.logout();
    await tester.pumpAndSettle();
    expect(find.text('Account A product'), findsNothing);
    expect(find.byKey(const ValueKey('field-5:148')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
    api.close();
  }, timeout: const Timeout(Duration(seconds: 30)));
}
