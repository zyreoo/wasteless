import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/merchant/order_actions.dart';
import 'package:flutter_application_1/pages/live_orders_page.dart';
import 'package:flutter_application_1/pages/live_product_page.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/services/commerce_service.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/live_page.dart';

http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  group('Visitor', () {
    testWidgets('browses an offer and is sent to sign-in to reserve it', (
      tester,
    ) async {
      final requests = <http.Request>[];
      final api = ApiService(
        baseUrl: 'https://example.invalid',
        accessToken: () async => null,
        client: MockClient((r) async {
          requests.add(r);
          return json({
            'id': 5,
            'name': 'Pachet surpriză de brutărie',
            'price': 19,
            'stock': 3,
          });
        }),
      );
      addTearDown(api.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: LiveProductPage(
            service: CommerceService(api, guest: true),
            id: 5,
          ),
          routes: {'/login': (_) => const Text('sign-in')},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pachet surpriză de brutărie'), findsOneWidget);
      await tester.ensureVisible(find.text('Autentifică-te pentru a rezerva'));
      await tester.tap(find.text('Autentifică-te pentru a rezerva'));
      await tester.pumpAndSettle();
      expect(find.text('sign-in'), findsOneWidget);
      // Only the public offer was requested, without a token.
      expect(requests.map((r) => r.url.path), ['/api/products/5']);
      expect(requests.single.headers['Authorization'], isNull);
    });

    test('account-only calls still need a session', () async {
      final api = ApiService(
        baseUrl: 'https://example.invalid',
        accessToken: () async => null,
        client: MockClient((_) async => fail('no request expected')),
      );
      await expectLater(
        CommerceService(api, guest: true).cart(),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
      );
    });
  });

  group('Pickup ended', () {
    final now = DateTime(2026, 10, 8, 21);
    Map<String, dynamic> order(String status, {String? end, String? placed}) =>
        {
          'id': 1,
          'status': status,
          'created_at': placed ?? DateTime(2026, 10, 8, 9).toIso8601String(),
          'pickup_end': end,
        };

    test('a dated window ends at its end time', () {
      final end = DateTime(2026, 10, 8, 20).toUtc().toIso8601String();
      expect(pickupEnded(order('ready', end: end), now: now), isTrue);
      final later = DateTime(2026, 10, 8, 22).toUtc().toIso8601String();
      expect(pickupEnded(order('ready', end: later), now: now), isFalse);
    });

    test('the usual daily window ends with the day the order was placed', () {
      expect(pickupEnded(order('confirmed'), now: now), isFalse);
      final yesterday = DateTime(2026, 10, 7, 9).toIso8601String();
      expect(
        pickupEnded(order('confirmed', placed: yesterday), now: now),
        isTrue,
      );
    });

    test('closed orders are never pending pickup', () {
      final end = DateTime(2026, 10, 8, 20).toUtc().toIso8601String();
      for (final status in ['collected', 'cancelled', 'not_collected']) {
        expect(pickupEnded(order(status, end: end), now: now), isFalse);
      }
    });

    testWidgets('the shop closes an order nobody picked up', (tester) async {
      final requests = <http.Request>[];
      final api = ApiService(
        baseUrl: 'https://example.invalid',
        accessToken: () async => 'token',
        client: MockClient((r) async {
          requests.add(r);
          return http.Response('', 204);
        }),
      );
      addTearDown(api.close);
      final ended = DateTime.now()
          .subtract(const Duration(hours: 1))
          .toUtc()
          .toIso8601String();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrderActions(
              order: {
                'id': 3,
                'status': 'ready',
                'created_at': DateTime.now().toIso8601String(),
                'pickup_end': ended,
              },
              service: CommerceService(api),
              merchant: true,
              reload: () async {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('Nu a fost ridicată'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Închide comanda'));
      await tester.pumpAndSettle();
      expect(requests.single.url.path, '/api/orders/3/status');
      expect(jsonDecode(requests.single.body)['status'], 'not_collected');
    });

    testWidgets('customers never get the not-collected action', (tester) async {
      final api = ApiService(
        baseUrl: 'https://example.invalid',
        accessToken: () async => 'token',
      );
      addTearDown(api.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrderActions(
              order: {
                'id': 3,
                'status': 'ready',
                'created_at': DateTime(2026, 1, 1).toIso8601String(),
              },
              service: CommerceService(api),
              reload: () async {},
            ),
          ),
        ),
      );
      expect(find.text('Nu a fost ridicată'), findsNothing);
      expect(find.text('Anulează comanda'), findsOneWidget);
    });

    testWidgets('a not-collected order reads as closed', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusPill('not_collected'),
                OrderProgress(status: 'not_collected'),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Neridicată'), findsOneWidget);
      expect(find.text('Comanda nu a fost ridicată'), findsOneWidget);
    });
  });

  group('Auto refresh', () {
    testWidgets('new data appears and a failed refresh keeps the page', (
      tester,
    ) async {
      var calls = 0;
      Future<String> load() async {
        calls++;
        if (calls == 3) throw const ApiException('offline');
        return 'version $calls';
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoadPanel<String>(
              load: load,
              refreshEvery: const Duration(seconds: 30),
              builder: (value, _) => Text(value),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('version 1'), findsOneWidget);
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(find.text('version 2'), findsOneWidget);
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(find.text('version 2'), findsOneWidget);
      expect(find.text('offline'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
