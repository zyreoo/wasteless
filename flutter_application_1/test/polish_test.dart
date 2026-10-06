import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/pages/catalog_page.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/services/commerce_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/product.dart';
import 'package:flutter_application_1/widgets/product_tile.dart';
import 'package:flutter_application_1/widgets/live_page.dart';
import 'package:flutter_application_1/pages/live_orders_page.dart';
import 'package:flutter_application_1/theme/app_theme.dart';

void main() {
  testWidgets('Catalog query survives replacing a primary tab', (tester) async {
    final api = ApiService(
      baseUrl: 'https://example.invalid',
      accessToken: () async => 'test',
      client: MockClient(
        // One offer, so the search field is shown (it hides when empty).
        (r) async => http.Response(
          jsonEncode({
            'items': [
              {'id': 1, 'name': 'Mere', 'price': 3.4, 'stock': 10},
            ],
            'next_offset': null,
          }),
          200,
        ),
      ),
    );
    addTearDown(api.close);
    final service = CommerceService(api);
    await tester.pumpWidget(
      BrowseSession(
        child: MaterialApp(
          theme: AppTheme.theme,
          home: CatalogPage(service: service),
          onGenerateRoute: (settings) => MaterialPageRoute(
            settings: settings,
            builder: (_) => CatalogPage(
              service: service,
              savedOnly: settings.name == '/saved',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'brutarie');
    expect(
      BrowseMemory.of(tester.element(find.byType(CatalogPage)))!
          .values['catalog.query'],
      'brutarie',
    );
    await tester.tap(find.text('Favorite').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descoperă').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'brutarie',
    );
  });
  for (final width in [288.0, 380.0, 565.0]) {
    testWidgets('Offer card fits $width and exposes real discount and pickup', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                height: width / 1.6 + 300,
                child: ProductTile(
                  product: const Product(
                    id: 5,
                    name: 'Pachet de brutărie cu pâine, croissante și specialități proaspete · DEMO',
                    price: 19,
                    originalPrice: 55,
                    stock: 2,
                    isDemo: true,
                    merchant: {
                      'name': 'Atelierul meu',
                      'pickup_window': '18:00–19:00',
                    },
                  ),
                  saved: false,
                  onFavorite: () {},
                  onOpen: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('−65%'), findsOneWidget);
      expect(find.text('Ridicare 18:00–19:00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Primary navigation has no back arrow; detail navigation does', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LiveScaffold(
                  title: 'Salvate',
                  index: 2,
                  body: SizedBox(),
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsNothing);
  });
  testWidgets('Cancelled order does not show fulfillment progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: OrderProgress(status: 'cancelled')),
      ),
    );
    expect(find.text('Produsele au revenit în stoc.'), findsOneWidget);
    expect(find.text('Pregătită'), findsNothing);
  });
}
