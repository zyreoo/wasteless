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
    final paths = <String>[];
    final api = ApiService(
      baseUrl: 'https://api.example.invalid',
      accessToken: auth.accessToken,
      client: MockClient((r) async {
        paths.add(r.url.path);
        expect(r.headers['Authorization'], isNull);
        return http.Response('{"items":[]}', 200);
      }),
    );
    await tester.pumpWidget(WastelessApp(auth: auth, api: api));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    Navigator.pushNamed(context, '/cart');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('field-5:148')), findsOneWidget);
    // Visitors only ever load the public catalogue.
    expect(paths.toSet(), {'/api/products'});
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
    api.close();
  }, timeout: const Timeout(Duration(seconds: 30)));
  testWidgets('Logout removes account data and protected navigation stack', (
    tester,
  ) async {
    // Realistic desktop window: the shop-first catalogue puts filters, the
    // distance line and a shop header above the first bag.
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
                      // Signed-in and visitor responses differ, so leftover
                      // account data would be visible after logout.
                      'name': r.headers['Authorization'] == null
                          ? 'Public offer'
                          : 'Account A product',
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
    expect(find.text('Public offer'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
    api.close();
  }, timeout: const Timeout(Duration(seconds: 30)));
}
