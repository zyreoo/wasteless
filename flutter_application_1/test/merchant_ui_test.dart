import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/merchant/merchant_dashboard.dart';
import 'package:flutter_application_1/merchant/order_actions.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/services/commerce_service.dart';
import 'package:flutter_application_1/theme/app_theme.dart';

void main() {
  final merchant = {
    'id': 1,
    'name': 'Brutăria Bunicii',
    'address': 'Strada Mihai Eminescu 54, București',
    'pickup_window': '19:00–20:00',
    'latitude': 44.4459,
    'longitude': 26.1015,
    'status': 'approved',
  };
  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets('Merchant publishes, edits and hides an offer at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // A small stateful backend: what the dashboard shows is what was saved.
      final products = <Map<String, dynamic>>[];
      final api = ApiService(
        baseUrl: 'https://example.invalid',
        accessToken: () async => 'token',
        client: MockClient((r) async {
          final path = r.url.path;
          if (r.method == 'POST' && path == '/api/merchant/products') {
            products.add({
              ...jsonDecode(r.body) as Map<String, dynamic>,
              'id': products.length + 1,
              'active': true,
            });
          } else if (r.method == 'PUT' &&
              path.startsWith('/api/merchant/products/')) {
            final id = int.parse(path.split('/').last);
            final i = products.indexWhere((p) => p['id'] == id);
            products[i] = {
              ...products[i],
              ...jsonDecode(r.body) as Map<String, dynamic>,
            };
          } else if (r.method == 'PATCH') {
            final id = int.parse(path.split('/').last);
            products.firstWhere((p) => p['id'] == id)['active'] = jsonDecode(
              r.body,
            )['active'];
          }
          return http.Response(
            jsonEncode(
              r.method == 'GET'
                  ? {'merchant': merchant, 'products': products, 'orders': []}
                  : {'id': products.length},
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(api.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: MerchantDashboard(service: CommerceService(api)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Publică primul pachet'), findsOneWidget);

      Future<void> fill(String label, String value) async {
        final field = find.widgetWithText(TextFormField, label);
        await tester.ensureVisible(field);
        await tester.enterText(field, value);
      }

      Future<void> save() async {
        await tester.ensureVisible(find.text('Salvează'));
        await tester.tap(find.text('Salvează'));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Adaugă ofertă'));
      await tester.pumpAndSettle();
      await fill('Nume', 'Pachet surpriză de patiserie');
      await fill('Preț redus (lei)', '18');
      await fill('Preț inițial (lei)', '54');
      await fill('Alergeni', 'Gluten, lapte, ouă');
      await save();
      expect(find.text('Pachet surpriză de patiserie'), findsOneWidget);
      expect(find.text('18,00 lei · 5 disponibile'), findsOneWidget);

      await tester.tap(find.text('Editează / stoc'));
      await tester.pumpAndSettle();
      await fill('Stoc disponibil (fără cantitățile deja rezervate)', '2');
      await save();
      expect(find.text('18,00 lei · 2 disponibile'), findsOneWidget);
      expect(products.single['stock'], 2);

      await tester.tap(find.text('Ascunde oferta'));
      await tester.pumpAndSettle();
      expect(products.single['active'], isFalse);
      expect(find.text('Publică oferta'), findsOneWidget);
      expect(find.textContaining('DEMO'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Customer cannot see merchant status controls', (tester) async {
    final api = ApiService(
      baseUrl: 'https://example.invalid',
      accessToken: () async => 'token',
      client: MockClient((r) async => http.Response('{}', 200)),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderActions(
            order: {'id': 1, 'status': 'ready'},
            service: CommerceService(api),
            reload: () async {},
          ),
        ),
      ),
    );
    expect(find.text('Verifică codul și finalizează'), findsNothing);
    expect(find.text('Anulează comanda'), findsOneWidget);
  });
}
