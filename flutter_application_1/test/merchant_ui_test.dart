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
    'name': 'Atelier Demo',
    'address': 'Strada Exemplu 10',
    'pickup_window': '18:00–19:00',
    'latitude': 44.435,
    'longitude': 26.102,
    'demo_seeded': false,
  };
  final product = {
    'id': 1,
    'name': 'Pachet demo',
    'price': 19,
    'stock': 8,
    'active': true,
  };
  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets('Merchant dashboard fits $width and supports seeding', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      bool seeded = false;
      final api = ApiService(
        baseUrl: 'https://example.invalid',
        accessToken: () async => 'token',
        client: MockClient((r) async {
          if (r.url.path.endsWith('/seed')) seeded = true;
          return http.Response(
            jsonEncode({
              'merchant': {...merchant, 'demo_seeded': seeded},
              'products': seeded ? [product] : [],
              'orders': [],
            }),
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
      await tester.ensureVisible(find.text('Adaugă exemple de test'));
      await tester.tap(find.text('Adaugă exemple de test'));
      await tester.pumpAndSettle();
      expect(seeded, isTrue);
      expect(find.text('Pachet demo'), findsOneWidget);
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
