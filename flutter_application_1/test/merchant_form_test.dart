import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/merchant/merchant_dashboard.dart';
import 'package:flutter_application_1/models/product.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/services/commerce_service.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/product_tile.dart';

void main() {
  testWidgets('Offer form stops values the server would reject', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(768, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var saves = 0;
    final api = ApiService(
      baseUrl: 'https://example.invalid',
      accessToken: () async => 'token',
      client: MockClient((r) async {
        saves++;
        return http.Response(jsonEncode({'id': 1}), 201);
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: MerchantEditor(service: CommerceService(api)),
      ),
    );

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

    await fill('Nume', 'Pachet de patiserie');
    await fill('Preț redus (lei)', '20');
    await fill('Preț inițial (lei)', '15');
    await fill('Alergeni', '-');
    await save();
    expect(
      find.text('Prețul inițial nu poate fi mai mic decât prețul redus.'),
      findsOneWidget,
    );
    expect(
      find.text('Scrie alergenii sau „Fără alergeni declarați”.'),
      findsOneWidget,
    );

    await fill('Preț inițial (lei)', '45,555');
    await save();
    expect(find.text('Maximum două zecimale, ex.: 14,50.'), findsOneWidget);
    expect(saves, 0);
  });

  test('Validation errors name the field to fix', () {
    final response = http.Response(
      jsonEncode({
        'detail': [
          {
            'loc': ['body', 'allergens'],
            'msg': 'String should have at least 2 characters',
          },
        ],
      }),
      422,
    );
    expect(ApiService.safeDetail(response), 'Verifică câmpul „Alergeni”.');
  });

  test('Generic bags get a photo that matches their contents', () {
    Product bag(String name, String category) => Product.fromJson({
      'id': 1,
      'name': name,
      'price': 10,
      'stock': 1,
      'category': category,
      'image_path': 'assets/demo/rescue-bag.webp',
    });
    expect(
      suggestedImage(bag('Pachet de poke și salate', 'Sushi')),
      'assets/demo/poke.jpg',
    );
    expect(
      suggestedImage(bag('Pachet de tort felii', 'Cofetărie')),
      'assets/demo/cake.jpg',
    );
    expect(
      suggestedImage(bag('Pachet de prăjituri la cafea', 'Cafenea')),
      'assets/demo/brownies.jpg',
    );
    expect(
      suggestedImage(bag('Coș de legume de sezon', 'Fructe și legume')),
      'assets/demo/vegetables.jpg',
    );
    expect(suggestedImage(bag('Pachet surpriză', 'Altele')), isNull);
  });
}
