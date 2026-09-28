import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/services/api_service.dart';

void main() {
  test(
    'Authenticated requests carry token and exact selected product',
    () async {
      final api = ApiService(
        baseUrl: 'https://api.example.invalid',
        accessToken: () async => 'token',
        client: MockClient((r) async {
          expect(r.method, 'POST');
          expect(r.url.path, '/api/cart/items');
          expect(r.headers['Authorization'], 'Bearer token');
          expect(jsonDecode(r.body), {
            'product_id': 'product-b',
            'quantity': 2,
          });
          return http.Response('{"id":"item-b"}', 201);
        }),
      );
      expect(
        await api.request(
          'POST',
          '/api/cart/items',
          body: {'product_id': 'product-b', 'quantity': 2},
        ),
        {'id': 'item-b'},
      );
      api.close();
    },
  );
  test('No session never sends a request', () async {
    final api = ApiService(
      baseUrl: 'https://api.example.invalid',
      accessToken: () async => null,
      client: MockClient((_) async => throw StateError('must not send')),
    );
    await expectLater(
      api.request('GET', '/api/cart'),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
    );
    api.close();
  });
  for (final status in [401, 403, 404, 409, 422, 429, 500, 503]) {
    test('HTTP $status returns safe message', () async {
      final api = ApiService(
        baseUrl: 'https://api.example.invalid',
        accessToken: () async => 'token',
        client: MockClient(
          (_) async => http.Response('private traceback', status),
        ),
      );
      await expectLater(
        api.request('GET', '/api/cart'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', status)
              .having(
                (e) => e.message,
                'message',
                isNot(contains('traceback')),
              ),
        ),
      );
      api.close();
    });
  }
  test('Timeout becomes useful message', () async {
    final api = ApiService(
      baseUrl: 'https://api.example.invalid',
      accessToken: () async => 'token',
      timeout: const Duration(milliseconds: 1),
      client: MockClient((_) => Completer<http.Response>().future),
    );
    await expectLater(
      api.request('GET', '/api/cart'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('prea mult'),
        ),
      ),
    );
    api.close();
  });
  test('204 supports delete without JSON', () async {
    final api = ApiService(
      baseUrl: 'https://api.example.invalid',
      accessToken: () async => 'token',
      client: MockClient((_) async => http.Response('', 204)),
    );
    expect(await api.request('DELETE', '/api/cart/items/b'), isNull);
    api.close();
  });
}
