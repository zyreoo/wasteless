import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/pages/catalog_page.dart';
import 'package:flutter_application_1/pages/live_orders_page.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/services/commerce_service.dart';
import 'package:flutter_application_1/theme/app_theme.dart';

Map<String, Object> product(int id, String name) => {
  'id': id,
  'name': name,
  'price': 3.4,
  'stock': 10,
};
Map<String, Object> order(int id) => {
  'id': id,
  'created_at': '2026-10-0${id}T10:00:00Z',
  'status': 'confirmed',
  'total_price': '10.00',
  'order_items': [
    {
      'id': id,
      'product_id': 1,
      'product_name': 'Mere',
      'quantity': 1,
      'unit_price': '10.00',
    },
  ],
};
http.Response json(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Scripted pages keyed by offset; records every offset requested.
class Pages {
  Pages(this.pages);
  final Map<int, ({List<int> ids, int? next})> pages;
  final requested = <int>[];
  Object? failNext;
  Future<ApiPage<int>> fetch(int offset) async {
    requested.add(offset);
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
    final page = pages[offset]!;
    return (items: page.ids, next: page.next);
  }
}

void main() {
  group('Pager', () {
    test('starts with one page and appends the next on demand', () async {
      final pages = Pages({
        0: (ids: [1, 2], next: 2),
        2: (ids: [3, 4], next: null),
      });
      final pager = Pager<int>(pages.fetch, (i) => i);
      expect(await pager.refresh(), [1, 2]);
      expect(pages.requested, [0]);
      expect(pager.hasMore, true);
      expect(await pager.more(), true);
      expect(pager.items, [1, 2, 3, 4]);
      expect(pager.hasMore, false);
      expect(await pager.more(), false);
      expect(pages.requested, [0, 2]);
    });

    test('items shifted between pages are not duplicated', () async {
      final pages = Pages({
        0: (ids: [1, 2], next: 2),
        2: (ids: [2, 3], next: null),
      });
      final pager = Pager<int>(pages.fetch, (i) => i);
      await pager.refresh();
      await pager.more();
      expect(pager.items, [1, 2, 3]);
    });

    test('an empty page stops loading even if the API offers more', () async {
      final pages = Pages({
        0: (ids: [1], next: 1),
        1: (ids: [], next: 2),
      });
      final pager = Pager<int>(pages.fetch, (i) => i);
      await pager.refresh();
      await pager.more();
      expect(pager.hasMore, false);
      expect(await pager.more(), false);
      expect(pages.requested, [0, 1]);
    });

    test('a failed page keeps loaded items and can be retried', () async {
      final pages = Pages({
        0: (ids: [1, 2], next: 2),
        2: (ids: [3], next: null),
      });
      final pager = Pager<int>(pages.fetch, (i) => i);
      await pager.refresh();
      pages.failNext = const ApiException('offline');
      await expectLater(pager.more(), throwsA(isA<ApiException>()));
      expect(pager.items, [1, 2]);
      expect(pager.hasMore, true);
      expect(pager.loading, false);
      await pager.more();
      expect(pager.items, [1, 2, 3]);
    });

    test('a failed refresh keeps the previous items', () async {
      final pages = Pages({
        0: (ids: [1, 2], next: null),
      });
      final pager = Pager<int>(pages.fetch, (i) => i);
      await pager.refresh();
      pages.failNext = const ApiException('offline');
      await expectLater(pager.refresh(), throwsA(isA<ApiException>()));
      expect(pager.items, [1, 2]);
    });

    test('refresh reloads as many items as the user had loaded', () async {
      final pages = Pages({
        0: (ids: [1, 2], next: 2),
        2: (ids: [3, 4], next: 4),
        4: (ids: [5], next: null),
      });
      final pager = Pager<int>(pages.fetch, (i) => i);
      await pager.refresh();
      await pager.more();
      pages.requested.clear();
      await pager.refresh();
      expect(pages.requested, [
        0,
        2,
      ], reason: 'not the third, unrequested page');
      expect(pager.items, [1, 2, 3, 4]);
      expect(pager.hasMore, true);
    });

    test('overlapping load-more calls send a single request', () async {
      final pages = Pages({
        0: (ids: [1], next: 1),
        1: (ids: [2], next: null),
      });
      final pager = Pager<int>(pages.fetch, (i) => i);
      await pager.refresh();
      await Future.wait([pager.more(), pager.more(), pager.more()]);
      expect(pages.requested, [0, 1]);
      expect(pager.items, [1, 2]);
    });
  });

  CommerceService service(
    http.Response Function(http.Request) respond,
    List<String> log,
  ) => CommerceService(
    ApiService(
      baseUrl: 'https://example.invalid',
      accessToken: () async => 'token',
      client: MockClient((r) async {
        log.add(
          '${r.method} ${r.url.path}${r.url.hasQuery ? '?${r.url.query}' : ''}',
        );
        return respond(r);
      }),
    ),
  );

  void wideView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget app(Widget home) => MaterialApp(theme: AppTheme.theme, home: home);

  testWidgets('Catalogue loads one page, then more on request, no duplicates', (
    tester,
  ) async {
    wideView(tester);
    final log = <String>[];
    final s = service((r) {
      if (r.url.path == '/api/favorites') return json({'items': []});
      return r.url.queryParameters['offset'] == '0'
          ? json({
              'items': [product(1, 'Mere'), product(2, 'Pere')],
              'next_offset': 2,
            })
          : json({
              'items': [product(2, 'Pere'), product(3, 'Prune')],
              'next_offset': null,
            });
    }, log);
    await tester.pumpWidget(app(CatalogPage(service: s)));
    await tester.pumpAndSettle();
    expect(find.text('Mere'), findsOneWidget);
    expect(find.text('Prune'), findsNothing);
    expect(log.where((l) => l.contains('/api/products')), [
      'GET /api/products?offset=0',
    ]);
    await tester.tap(find.byKey(const ValueKey('load-more')));
    await tester.pumpAndSettle();
    expect(find.text('Prune'), findsOneWidget);
    expect(find.text('Pere'), findsOneWidget);
    expect(find.byKey(const ValueKey('load-more')), findsNothing);
    expect(log.where((l) => l.contains('/api/products')), [
      'GET /api/products?offset=0',
      'GET /api/products?offset=2',
    ]);
  });

  void phoneView(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Twelve products on page one: long enough that scrolling reaches the end.
  final firstPage = [for (var i = 1; i <= 12; i++) product(i, 'Produs $i')];
  int productRequests(List<String> log) =>
      log.where((l) => l.contains('/api/products')).length;
  Future<void> scrollToEnd(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets('Scrolling near the end loads the next page by itself', (
    tester,
  ) async {
    phoneView(tester);
    final log = <String>[];
    final s = service((r) {
      if (r.url.path == '/api/favorites') return json({'items': []});
      return r.url.queryParameters['offset'] == '0'
          ? json({'items': firstPage, 'next_offset': 12})
          : json({
              'items': [product(13, 'Produs 13')],
              'next_offset': null,
            });
    }, log);
    await tester.pumpWidget(app(CatalogPage(service: s)));
    await tester.pumpAndSettle();
    expect(productRequests(log), 1);
    await scrollToEnd(tester);
    expect(log.where((l) => l.contains('/api/products')), [
      'GET /api/products?offset=0',
      'GET /api/products?offset=12',
    ]);
    expect(find.text('Produs 13'), findsOneWidget);
    // Last page reached: further scrolling sends nothing.
    await scrollToEnd(tester);
    expect(productRequests(log), 2);
  });

  testWidgets(
    'A failed page keeps the catalogue and does not retry by itself',
    (tester) async {
      phoneView(tester);
      final log = <String>[];
      var failSecond = true;
      final s = service((r) {
        if (r.url.path == '/api/favorites') return json({'items': []});
        if (r.url.queryParameters['offset'] == '0') {
          return json({'items': firstPage, 'next_offset': 12});
        }
        return failSecond
            ? http.Response('', 503, headers: {'retry-after': '30'})
            : json({
                'items': [product(13, 'Produs 13')],
                'next_offset': null,
              });
      }, log);
      await tester.pumpWidget(app(CatalogPage(service: s)));
      await tester.pumpAndSettle();
      await scrollToEnd(tester);
      expect(productRequests(log), 2, reason: 'scrolling tried page two once');
      expect(
        find.text('Serviciul nu este disponibil momentan. Încearcă din nou.'),
        findsOneWidget,
      );
      expect(find.text('Produs 12'), findsOneWidget);
      // Keep scrolling at the end: a failed page must not retry per scroll.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 400));
      await tester.pump();
      await scrollToEnd(tester);
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(productRequests(log), 2, reason: 'no automatic retry');
      failSecond = false;
      await tester.tap(find.byKey(const ValueKey('load-more')));
      await tester.pumpAndSettle();
      expect(find.text('Produs 13'), findsOneWidget);
      expect(find.text('Produs 12'), findsOneWidget);
      expect(productRequests(log), 3);
    },
  );

  testWidgets('Saving a product does not refetch the catalogue', (
    tester,
  ) async {
    wideView(tester);
    final log = <String>[];
    final s = service((r) {
      if (r.method == 'POST') return http.Response('', 204);
      if (r.url.path == '/api/favorites') return json({'items': []});
      return json({
        'items': [product(1, 'Mere')],
        'next_offset': null,
      });
    }, log);
    await tester.pumpWidget(app(CatalogPage(service: s)));
    await tester.pumpAndSettle();
    final before = log.length;
    await tester.tap(find.byTooltip('Salvează produsul'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Elimină din favorite'), findsOneWidget);
    expect(log.sublist(before), ['POST /api/favorites']);
  });

  testWidgets('Order history starts with the newest page only', (tester) async {
    wideView(tester);
    final log = <String>[];
    final s = service((r) {
      return r.url.queryParameters['offset'] == '0'
          ? json({
              'items': [order(2)],
              'next_offset': 1,
            })
          : json({
              'items': [order(1)],
              'next_offset': null,
            });
    }, log);
    await tester.pumpWidget(app(LiveOrdersPage(service: s)));
    await tester.pumpAndSettle();
    expect(find.text('Comanda #2'), findsOneWidget);
    expect(find.text('Comanda #1'), findsNothing);
    expect(log, ['GET /api/orders?offset=0']);
    await tester.tap(find.byKey(const ValueKey('load-older-orders')));
    await tester.pumpAndSettle();
    expect(find.text('Comanda #1'), findsOneWidget);
    expect(find.byKey(const ValueKey('load-older-orders')), findsNothing);
    expect(log, ['GET /api/orders?offset=0', 'GET /api/orders?offset=1']);
  });
}
