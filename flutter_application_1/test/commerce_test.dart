import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/services/commerce_service.dart';
import 'package:flutter_application_1/pages/catalog_page.dart';
import 'package:flutter_application_1/pages/live_product_page.dart';
import 'package:flutter_application_1/pages/live_cart_page.dart';
import 'package:flutter_application_1/pages/live_checkout_page.dart';
import 'package:flutter_application_1/theme/app_theme.dart';

const a = {'id': 1, 'name': 'Mere', 'price': 3.4, 'stock': 10};
const b = {'id': 2, 'name': 'Pere', 'price': 2.8, 'stock': 10};
http.Response json(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
CommerceService service(Future<http.Response> Function(http.Request) handle) =>
    CommerceService(
      ApiService(
        baseUrl: 'https://example.invalid',
        accessToken: () async => 'token',
        client: MockClient(handle),
      ),
    );
Widget app(
  Widget home, {
  Map<String, WidgetBuilder> routes = const {},
  double scale = 1,
}) => MaterialApp(
  theme: AppTheme.theme,
  home: home,
  routes: routes,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
);
void main() {
  testWidgets('Favorites show A and B, remove only the selected favorite', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final saved = [a, b];
    final s = service((r) async {
      if (r.method == 'DELETE') {
        saved.removeWhere((p) => r.url.path.endsWith('/${p['id']}'));
        return http.Response('', 204);
      }
      return json({'items': saved});
    });
    await tester.pumpWidget(app(CatalogPage(service: s, savedOnly: true)));
    await tester.pumpAndSettle();
    expect(find.text('Mere'), findsOneWidget);
    expect(find.text('Pere'), findsOneWidget);
    await tester.tap(find.byTooltip('Elimină din favorite').first);
    await tester.pumpAndSettle();
    expect(find.text('Mere'), findsNothing);
    expect(find.text('Pere'), findsOneWidget);
  });
  testWidgets('Product detail adds requested product, never first product', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Object? added;
    final s = service((r) async {
      if (r.method == 'POST') {
        added = jsonDecode(r.body);
        return json({});
      }
      if (r.url.path == '/api/favorites') return json({'items': []});
      expect(r.url.path, '/api/products/2');
      return json(b);
    });
    await tester.pumpWidget(
      app(
        LiveProductPage(id: 2, service: s),
        routes: {
          '/cart': (_) => const Scaffold(body: Text('Cart destination')),
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Adaugă în coș'));
    await tester.tap(find.text('Adaugă în coș'));
    await tester.pumpAndSettle();
    expect(added, {'product_id': 2, 'quantity': 1});
    expect(find.text('Cart destination'), findsOneWidget);
  });
  testWidgets('Failed add never displays success or opens cart', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = service(
      (r) async => r.method == 'POST'
          ? json({}, 409)
          : r.url.path == '/api/favorites'
          ? json({'items': []})
          : json(b),
    );
    await tester.pumpWidget(app(LiveProductPage(id: 2, service: s)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Adaugă în coș'));
    await tester.tap(find.text('Adaugă în coș'));
    await tester.pumpAndSettle();
    expect(find.text('Produs adăugat în coș'), findsNothing);
    expect(
      find.text('Datele s-au schimbat. Reîncarcă și încearcă din nou.'),
      findsOneWidget,
    );
  });
  testWidgets('Decreasing quantity one removes item and shows empty state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    bool removed = false;
    final s = service((r) async {
      if (r.method == 'PATCH') {
        expect(jsonDecode(r.body), {'quantity': 0});
        removed = true;
        return json({});
      }
      return json({
        'items': removed
            ? []
            : [
                {
                  'id': 7,
                  'quantity': 1,
                  'product': a,
                  'available': true,
                  'line_total': '3.40',
                },
              ],
        'total': '3.40',
        'can_checkout': true,
      });
    });
    await tester.pumpWidget(app(LiveCartPage(service: s)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Elimină produsul'));
    await tester.pumpAndSettle();
    expect(find.text('Coșul tău este gol'), findsOneWidget);
  });
  testWidgets(
    'Checkout disables double submit and passes stable idempotency key',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int requests = 0;
      String? key;
      final response = Completer<http.Response>();
      final s = service((r) async {
        if (r.method == 'POST') {
          requests++;
          key = r.headers['Idempotency-Key'];
          return response.future;
        }
        return json({
          'items': [
            {'product': a, 'quantity': 1, 'line_total': '3.40'},
          ],
          'total': '3.40',
          'can_checkout': true,
        });
      });
      await tester.pumpWidget(
        app(
          LiveCheckoutPage(service: s),
          routes: {
            '/order-confirm': (_) => const Scaffold(body: Text('Confirmed')),
          },
        ),
      );
      await tester.pumpAndSettle();
      final button = find.widgetWithText(FilledButton, 'Confirmă comanda');
      await tester.tap(button);
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(requests, 1);
      expect(key, matches(RegExp(r'^[a-f0-9-]{36}$')));
      response.complete(json({'id': 42}, 201));
      await tester.pumpAndSettle();
      expect(find.text('Confirmed'), findsOneWidget);
    },
  );
  testWidgets('Catalogue accommodates large accessibility text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = service(
      (r) async => json({
        'items': r.url.path.endsWith('favorites') ? [] : [a],
      }),
    );
    await tester.pumpWidget(app(CatalogPage(service: s), scale: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
