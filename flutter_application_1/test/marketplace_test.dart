import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/discovery/legal_pages.dart';
import 'package:flutter_application_1/discovery/location.dart';
import 'package:flutter_application_1/merchant/merchant_dashboard.dart';
import 'package:flutter_application_1/models/product.dart';
import 'package:flutter_application_1/pages/catalog_page.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/services/commerce_service.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/product_tile.dart';

const bucharest = (lat: 44.4268, lng: 26.1025);
const cluj = (lat: 46.7712, lng: 23.6236);

Map<String, Object?> shop(int id, String name, double lat, double lng) => {
  'id': id,
  'name': name,
  'address': 'Zona $name, București',
  'pickup_window': '19:00–20:00',
  'latitude': lat,
  'longitude': lng,
};

Map<String, Object?> bag(
  int id,
  String name,
  Map<String, Object?> merchant, {
  DateTime? start,
  DateTime? end,
}) => {
  'id': id,
  'name': name,
  'price': 15,
  'original_price': 45,
  'stock': 5,
  'merchant_id': merchant['id'],
  'merchants': merchant,
  'pickup_start': start?.toUtc().toIso8601String(),
  'pickup_end': end?.toUtc().toIso8601String(),
};

http.Response json(Object data) => http.Response.bytes(
  utf8.encode(jsonEncode(data)),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class FixedLocation implements LocationProvider {
  FixedLocation(this.point);
  final GeoPoint? point;
  int calls = 0;
  @override
  Future<GeoPoint?> current() async {
    calls++;
    return point;
  }
}

void main() {
  setUp(NearbyLocation.instance.reset);

  group('Pickup windows', () {
    final now = DateTime(2026, 10, 7, 12);
    test('dated windows read as today, tomorrow or a date', () {
      expect(
        pickupWindowLabel(
          DateTime(2026, 10, 7, 19),
          DateTime(2026, 10, 7, 20, 30),
          now: now,
        ),
        'Azi, 19:00–20:30',
      );
      expect(
        pickupWindowLabel(
          DateTime(2026, 10, 8, 8, 5),
          DateTime(2026, 10, 8, 9),
          now: now,
        ),
        'Mâine, 08:05–09:00',
      );
      expect(
        pickupWindowLabel(
          DateTime(2026, 10, 10, 19),
          DateTime(2026, 10, 10, 20),
          now: now,
        ),
        '10.10, 19:00–20:00',
      );
      expect(pickupWindowLabel(null, null), isNull);
    });

    test('undated bags fall back to the shop window', () {
      final p = Product.fromJson(bag(1, 'Pachet', shop(1, 'A', 44, 26)));
      expect(p.pickupLabel, '19:00–20:00');
    });

    test('time filters use dated windows and the shop usual window', () {
      final s = shop(1, 'A', 44, 26);
      final tomorrow = Product.fromJson(
        bag(
          1,
          'Mâine',
          s,
          start: DateTime(2026, 10, 8, 19),
          end: DateTime(2026, 10, 8, 20),
        ),
      );
      final openNow = Product.fromJson(
        bag(
          2,
          'Acum',
          s,
          start: DateTime(2026, 10, 7, 11, 30),
          end: DateTime(2026, 10, 7, 13),
        ),
      );
      final usual = Product.fromJson(bag(3, 'Obișnuit', s));
      bool m(Product p, PickupWhen w) => matchesWhen(p, w, now: now);
      expect(m(tomorrow, PickupWhen.tomorrow), isTrue);
      expect(m(tomorrow, PickupWhen.today), isFalse);
      expect(m(openNow, PickupWhen.now), isTrue);
      expect(m(openNow, PickupWhen.today), isTrue);
      // The shop's usual 19:00–20:00 is today, but not within the next hour.
      expect(m(usual, PickupWhen.today), isTrue);
      expect(m(usual, PickupWhen.now), isFalse);
      expect(
        m(usual, PickupWhen.now),
        matchesWhen(usual, PickupWhen.now, now: DateTime(2026, 10, 7, 12)),
      );
      expect(
        matchesWhen(usual, PickupWhen.now, now: DateTime(2026, 10, 7, 18, 30)),
        isTrue,
      );
    });
  });

  group('Distance', () {
    test('haversine distance and labels', () {
      expect(distanceKm(bucharest, cluj), closeTo(324, 10));
      expect(distanceKm(bucharest, bucharest), 0);
      expect(distanceLabel(0.34), '350 m');
      expect(distanceLabel(1.24), '1,2 km');
      expect(distanceLabel(12.4), '12 km');
    });
  });

  group('Shop-first discovery', () {
    // Near is ~0.5 km from the user's position, Far ~6 km; from the city
    // centre the order is reversed.
    final near = shop(1, 'Aproape', 44.4700, 26.0600);
    final far = shop(2, 'Departe', 44.4300, 26.1050);
    final user = (lat: 44.4740, lng: 26.0620);
    final tomorrow = DateUtils.dateOnly(DateTime.now())
        .add(const Duration(days: 1, hours: 19));

    late List<http.Request> requests;
    CommerceService service() {
      requests = [];
      return CommerceService(
        ApiService(
          baseUrl: 'https://example.invalid',
          accessToken: () async => 'token',
          client: MockClient((r) async {
            requests.add(r);
            if (r.url.path == '/api/favorites') return json({'items': []});
            return json({
              'items': [
                bag(1, 'Pachet de la Departe', far),
                bag(
                  2,
                  'Pachet de mâine',
                  near,
                  start: tomorrow,
                  end: tomorrow.add(const Duration(hours: 1)),
                ),
                bag(3, 'Pachet de la Aproape', near),
              ],
              'next_offset': null,
            });
          }),
        ),
      );
    }

    Future<void> pump(WidgetTester tester, LocationProvider location) async {
      tester.view.physicalSize = const Size(1280, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: CatalogPage(service: service(), location: location),
        ),
      );
      await tester.pumpAndSettle();
    }

    double top(WidgetTester tester, String text) =>
        tester.getTopLeft(find.text(text).first).dy;

    testWidgets('groups bags by shop and orders shops by distance', (
      tester,
    ) async {
      final location = FixedLocation(user);
      await pump(tester, location);
      expect(find.text('3 pachete · 2 magazine'), findsOneWidget);
      // From the city centre, Departe is nearer.
      expect(top(tester, 'Departe'), lessThan(top(tester, 'Aproape')));
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('distance-reference')))
            .data,
        contains('centrul orașului'),
      );
      await tester.tap(find.byKey(const ValueKey('use-location')));
      await tester.pumpAndSettle();
      expect(location.calls, 1);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('distance-reference')))
            .data,
        'Distanțe față de locația ta',
      );
      expect(top(tester, 'Aproape'), lessThan(top(tester, 'Departe')));
      // The user's position never leaves the device.
      for (final r in requests) {
        expect(r.url.toString(), isNot(contains('44.474')));
        expect(r.body, isNot(contains('44.474')));
      }
    });

    testWidgets('denied location keeps the city centre and says so', (
      tester,
    ) async {
      await pump(tester, FixedLocation(null));
      await tester.tap(find.byKey(const ValueKey('use-location')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nu am putut accesa locația'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('distance-reference')))
            .data,
        contains('centrul orașului'),
      );
    });

    testWidgets('time filter shows only the matching bags', (tester) async {
      await pump(tester, FixedLocation(user));
      await tester.tap(find.byKey(const ValueKey('when-tomorrow')));
      await tester.pumpAndSettle();
      expect(find.text('Pachet de mâine'), findsOneWidget);
      expect(find.text('Pachet de la Departe'), findsNothing);
      expect(find.text('1 pachet · 1 magazin'), findsOneWidget);
    });
  });

  testWidgets('a shop photo stands for its bags', (tester) async {
    const url =
        'https://x.supabase.co/storage/v1/object/public/shop-images/u/a.webp';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: ProductTile(
              product: Product.fromJson(
                bag(1, 'Pachet', {...shop(1, 'A', 44, 26), 'image_url': url}),
              ),
              saved: false,
              onFavorite: null,
              onOpen: () {},
            ),
          ),
        ),
      ),
    );
    final images = tester.widgetList<Image>(find.byType(Image));
    expect(
      images.any(
        (i) => i.image is NetworkImage && (i.image as NetworkImage).url == url,
      ),
      isTrue,
    );
  });

  group('Merchant', () {
    late List<http.Request> requests;
    CommerceService service(String status) {
      requests = [];
      return CommerceService(
        ApiService(
          baseUrl: 'https://example.invalid',
          accessToken: () async => 'token',
          client: MockClient((r) async {
            requests.add(r);
            return json({
              'merchant': {
                ...shop(1, 'Cuptorul Urban', 44, 26),
                'status': status,
              },
              'products': [],
              'orders': [],
            });
          }),
        ),
      );
    }

    testWidgets('a pending shop is told its bags are not public yet', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: MerchantDashboard(service: service('pending')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('În verificare'), findsOneWidget);
      expect(find.byKey(const ValueKey('approval-notice')), findsOneWidget);
    });

    testWidgets('an approved shop shows no approval notice', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: MerchantDashboard(service: service('approved')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('În verificare'), findsNothing);
      expect(find.byKey(const ValueKey('approval-notice')), findsNothing);
    });

    testWidgets('the chosen photo is uploaded as image bytes', (tester) async {
      final bytes = [0xff, 0xd8, 0xff, 0xe0, 1, 2, 3];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: MerchantDashboard(
            service: service('approved'),
            pickPhoto: () async => (bytes: bytes, contentType: 'image/jpeg'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('shop-photo')));
      await tester.tap(find.byKey(const ValueKey('shop-photo')));
      await tester.pumpAndSettle();
      final upload = requests.singleWhere(
        (r) => r.method == 'POST' && r.url.path == '/api/merchant/photo',
      );
      expect(upload.headers['Content-Type'], 'image/jpeg');
      expect(upload.bodyBytes, bytes);
    });

    testWidgets('an oversized photo is refused before upload', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: MerchantDashboard(
            service: service('approved'),
            pickPhoto: () async => (
              bytes: List.filled(2 * 1024 * 1024 + 1, 0),
              contentType: 'image/png',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('shop-photo')));
      await tester.tap(find.byKey(const ValueKey('shop-photo')));
      await tester.pumpAndSettle();
      expect(find.text('Imaginea poate avea cel mult 2 MB.'), findsOneWidget);
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
    });

    testWidgets('a bag for tomorrow is sent with its local pickup time', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      requests = [];
      final api = CommerceService(
        ApiService(
          baseUrl: 'https://example.invalid',
          accessToken: () async => 'token',
          client: MockClient((r) async {
            requests.add(r);
            return json({'id': 9});
          }),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: MerchantEditor(service: api),
        ),
      );
      await tester.enterText(
        find.byType(TextFormField).first,
        'Pachet de gustări de seară',
      );
      await tester.tap(find.byKey(const ValueKey('pickup-day')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mâine').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('pickup-from')),
        '20:30',
      );
      await tester.enterText(find.byKey(const ValueKey('pickup-to')), '21:30');
      await tester.tap(find.text('Salvează în backend'));
      await tester.pumpAndSettle();
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      final start = DateTime.parse(body['pickup_start']).toLocal();
      final end = DateTime.parse(body['pickup_end']).toLocal();
      final tomorrow = DateUtils.dateOnly(DateTime.now())
          .add(const Duration(days: 1));
      expect(DateUtils.dateOnly(start), tomorrow);
      expect((start.hour, start.minute), (20, 30));
      expect((end.hour, end.minute), (21, 30));
      expect(body['pickup_start'], endsWith('Z'));
    });
  });

  testWidgets('legal pages are marked as preliminary', (tester) async {
    for (final page in const [TermsPage(), PrivacyPage()]) {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.theme, home: page));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('legal-draft-notice')), findsOneWidget);
    }
    expect(find.textContaining('nu o păstrăm'), findsOneWidget);
  });
}
