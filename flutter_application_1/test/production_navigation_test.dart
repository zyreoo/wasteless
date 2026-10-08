import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/auth/auth_controller.dart';
import 'package:flutter_application_1/discovery/legal_pages.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/pages/catalog_page.dart';
import 'package:flutter_application_1/pages/design_page.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/widgets/figma_layout.dart';

SupabaseClient supabase() => SupabaseClient(
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(FigmaDesign.load);
  // Clients created inside a widget test's fake-async zone never finish
  // disposing, so each test gets one from setUp.
  late SupabaseClient c;
  setUp(() => c = supabase());
  tearDown(() => c.dispose());

  Future<(AuthController, ApiService, SupabaseClient)> start(
    WidgetTester tester, {
    required bool signedIn,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = AuthController(c);
    if (signedIn) await auth.login('a@example.invalid', 'password');
    final api = ApiService(
      baseUrl: 'https://api.example.invalid',
      accessToken: auth.accessToken,
      client: MockClient(
        (r) async => http.Response(
          r.url.path == '/api/me'
              ? '{"id":"x","email":"a@example.invalid"}'
              : r.url.path.contains('dashboard')
              ? '{"merchant":null,"products":[],"orders":[]}'
              : '{"items":[]}',
          200,
        ),
      ),
    );
    await tester.pumpWidget(WastelessApp(auth: auth, api: api));
    await tester.pumpAndSettle();
    return (auth, api, c);
  }

  Future<void> stop(
    WidgetTester tester,
    (AuthController, ApiService, SupabaseClient) app,
  ) async {
    await tester.pumpWidget(const SizedBox());
    app.$2.close();
    app.$1.dispose();
  }

  Future<void> open(
    WidgetTester tester,
    String route, [
    Object? arguments,
  ]) async {
    final context = tester.element(find.byType(Scaffold).first);
    Navigator.pushNamed(context, route, arguments: arguments);
    await tester.pumpAndSettle();
  }

  for (final signedIn in [false, true]) {
    final who = signedIn ? 'signed-in' : 'signed-out';
    testWidgets('No route renders a Figma prototype screen ($who)', (
      tester,
    ) async {
      final app = await start(tester, signedIn: signedIn);
      // Every prototype route plus the auth routes. Map screens are real
      // pages (never DesignPage) and need network tiles, so they are skipped.
      const mapScreens = {'/search', '/explore', '/map'};
      for (final route in [
        ...designRoutes.keys.where((r) => !mapScreens.contains(r)),
        '/forgot-password',
        '/reset-password',
        '/screens',
        '/inventory',
        '/community',
      ]) {
        await open(tester, route);
        // The production DesignPage is only the accessible auth form.
        for (final page in tester.widgetList<DesignPage>(
          find.byType(DesignPage, skipOffstage: false),
        )) {
          expect(page.auth, isNotNull, reason: '$route rendered a prototype');
        }
        expect(tester.takeException(), isNull, reason: route);
      }
      await stop(tester, app);
    }, timeout: const Timeout(Duration(seconds: 60)));
  }

  testWidgets('Signed-in users never see illustrative merchants', (
    tester,
  ) async {
    final app = await start(tester, signedIn: true);
    await open(tester, '/merchant', 'atelier');
    expect(find.text('Atelierul de pâine'), findsNothing);
    expect(find.textContaining('DEMO'), findsNothing);
    await stop(tester, app);
  });

  testWidgets('Visitors start on the real catalogue, not the sign-in form', (
    tester,
  ) async {
    final app = await start(tester, signedIn: false);
    expect(find.byType(CatalogPage), findsOneWidget);
    expect(find.byKey(const ValueKey('field-5:148')), findsNothing);
    await open(tester, '/merchant', 'atelier');
    expect(find.text('Atelierul de pâine'), findsNothing);
    await stop(tester, app);
  });

  testWidgets('Terms and privacy open for signed-out visitors', (tester) async {
    final app = await start(tester, signedIn: false);
    await open(tester, '/terms');
    expect(find.byType(TermsPage), findsOneWidget);
    await open(tester, '/privacy');
    expect(find.byType(PrivacyPage), findsOneWidget);
    await stop(tester, app);
  });
}
