import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/pages/catalog_page.dart';
import 'package:flutter_application_1/pages/live_cart_page.dart';
import 'package:flutter_application_1/pages/live_checkout_page.dart';
import 'package:flutter_application_1/pages/live_orders_page.dart';
import 'package:flutter_application_1/pages/live_product_page.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/services/commerce_service.dart';
import 'package:flutter_application_1/theme/app_theme.dart';

const merchant = {
  'id': 1,
  'name': 'Brutăria Cartierului din Centrul Vechi',
  'address': 'Strada Episcopiei nr. 4, Sector 1, București',
  'pickup_window': '18:00–19:30',
};
Map<String, Object> product(int id, {int stock = 6}) => {
  'id': id,
  'name': 'Pachet de brutărie cu pâine, croissante și specialități',
  'description': 'Pâine, croissante și specialități rămase la finalul zilei.',
  'image_path': 'assets/demo/rescue-bag.webp',
  'price': '19.00',
  'original_price': '55.00',
  'stock': stock,
  'category': 'Brutărie',
  'allergens': 'Gluten, lapte, ouă, susan, soia',
  'merchant_id': 1,
  'merchants': merchant,
};
final cartItem = {
  'id': 9,
  'quantity': 12,
  'product_id': 1,
  'product': product(1, stock: 20),
  'line_total': '228.00',
  'available': true,
};
final order = {
  'id': 104000,
  'created_at': '2026-10-09T10:00:00Z',
  'status': 'ready',
  'total_price': '228.00',
  'merchant_name': merchant['name'],
  'pickup_address': merchant['address'],
  'pickup_window': merchant['pickup_window'],
  'pickup_code': '7F3K2Q9A',
  'cancellation_reason': null,
  'order_items': [
    {
      'id': 1,
      'product_id': 1,
      'product_name': product(1)['name'],
      'quantity': 12,
      'unit_price': '19.00',
    },
  ],
};

CommerceService service() => CommerceService(
  ApiService(
    baseUrl: 'https://example.invalid',
    accessToken: () async => 'token',
    client: MockClient((r) async {
      final path = r.url.path;
      final Object body = switch (path) {
        '/api/favorites' => {'items': []},
        '/api/products' => {
          'items': [product(1), product(2, stock: 2), product(3, stock: 0)],
          'next_offset': null,
        },
        '/api/cart' => {
          'items': [cartItem],
          'total': '228.00',
          'can_checkout': true,
          'single_merchant': true,
        },
        '/api/orders' => {
          'items': [order],
          'next_offset': null,
        },
        _ when path.startsWith('/api/orders/') => order,
        _ => product(1),
      };
      return http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  ),
);

void main() {
  final screens = <String, Widget Function()>{
    'catalogue': () => CatalogPage(service: service()),
    'product': () => LiveProductPage(service: service(), id: 1),
    'cart': () => LiveCartPage(service: service()),
    'checkout': () => LiveCheckoutPage(service: service()),
    'confirmation': () =>
        LiveOrderDetailPage(service: service(), id: 104000, confirmation: true),
    'order history': () => LiveOrdersPage(service: service()),
  };
  for (final entry in screens.entries) {
    for (final (width, height, scale) in [
      (320.0, 640.0, 1.0),
      (375.0, 812.0, 1.0),
      (375.0, 812.0, 1.3),
      (768.0, 1024.0, 1.0),
      (1024.0, 768.0, 1.0),
      (1440.0, 900.0, 1.0),
    ]) {
      testWidgets(
        '${entry.key} lays out without overflow at ${width.toInt()}px, text ×$scale',
        (tester) async {
          tester.view.physicalSize = Size(width, height);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.theme,
              home: entry.value(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          // Scroll through the whole screen so lower sections lay out too.
          final scrollable = find.byType(Scrollable).first;
          for (var i = 0; i < 6; i++) {
            await tester.drag(scrollable, const Offset(0, -500));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
}
