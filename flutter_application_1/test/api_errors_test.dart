import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/services/api_service.dart';

http.Response body(Object data, int status, {Map<String, String>? headers}) =>
    http.Response(
      jsonEncode(data),
      status,
      headers: {'content-type': 'application/json; charset=utf-8', ...?headers},
    );

void main() {
  late int sent;
  ApiService api(http.Response Function() respond) => ApiService(
    baseUrl: 'https://api.example.invalid',
    accessToken: () async => 'token',
    client: MockClient((_) async {
      sent++;
      return respond();
    }),
  );
  setUp(() => sent = 0);

  Future<ApiException> failure(ApiService service) async {
    try {
      await service.request('POST', '/api/orders');
    } on ApiException catch (error) {
      return error;
    } finally {
      service.close();
    }
    fail('request should have failed');
  }

  test('409 shows the stock message the API wrote', () async {
    final error = await failure(
      api(
        () =>
            body({'detail': 'Stoc insuficient. Actualizează cantitatea.'}, 409),
      ),
    );
    expect(error.status, 409);
    expect(error.message, 'Stoc insuficient. Actualizează cantitatea.');
  });

  test('422 shows the pickup-code message the API wrote', () async {
    final error = await failure(
      api(() => body({'detail': 'Codul de ridicare nu este corect.'}, 422)),
    );
    expect(error.message, 'Codul de ridicare nu este corect.');
  });

  test('Validation lists fall back to the generic 422 message', () async {
    final error = await failure(
      api(
        () => body({
          'detail': [
            {
              'type': 'int_parsing',
              'loc': ['body', 'quantity'],
              'msg': 'Input should be a valid integer',
            },
          ],
        }, 422),
      ),
    );
    expect(error.message, 'Verifică datele introduse.');
    expect(error.message, isNot(contains('quantity')));
  });

  test('Malformed and detail-less bodies fall back safely', () async {
    for (final response in [
      http.Response('{"detail": "Stoc', 409),
      http.Response('<html>502 Bad Gateway</html>', 409),
      body({'message': 'Insufficient stock'}, 409),
      body(['detail'], 409),
      body({'detail': null}, 409),
      body({'detail': '   '}, 409),
      http.Response.bytes([0xff, 0xfe, 0x00], 409),
    ]) {
      final error = await failure(api(() => response));
      expect(
        error.message,
        'Datele s-au schimbat. Reîncarcă și încearcă din nou.',
      );
    }
  });

  test('Technical or framework details never reach the user', () async {
    for (final detail in [
      'duplicate key value violates unique constraint "order_pkey"',
      'select * from public.order where id = 1',
      'JWT expired',
      'Bearer eyJhbGciOiJIUzI1NiJ9.e30.x',
      'Fetch failed: https://abc.supabase.co/rest/v1/order',
      'PostgrestException(message: permission denied)',
      'Traceback (most recent call last)',
      'Not Found',
      'Internal Server Error',
      'line one\nline two',
      'x' * 201,
    ]) {
      final error = await failure(api(() => body({'detail': detail}, 404)));
      expect(
        error.message,
        'Elementul nu mai este disponibil.',
        reason: detail,
      );
    }
  });

  test('429 tells the user how long to wait and is never retried', () async {
    final error = await failure(
      api(
        () => body(
          {'detail': 'Prea multe cereri. Încearcă din nou în curând.'},
          429,
          headers: {'retry-after': '12'},
        ),
      ),
    );
    expect(error.status, 429);
    expect(error.retryAfter, const Duration(seconds: 12));
    expect(
      error.message,
      'Prea multe solicitări. Încearcă din nou în 12 secunde.',
    );
    expect(sent, 1);
  });

  test('429 without a usable Retry-After stays friendly', () async {
    for (final header in [
      null,
      'Wed, 21 Oct 2026 07:28:00 GMT',
      '0',
      '-5',
      '99999',
    ]) {
      sent = 0;
      final error = await failure(
        api(
          () => body(
            {},
            429,
            headers: header == null ? null : {'retry-after': header},
          ),
        ),
      );
      expect(error.retryAfter, isNull, reason: header);
      expect(
        error.message,
        'Prea multe solicitări. Încearcă din nou în câteva secunde.',
      );
      expect(sent, 1);
    }
  });

  test('401 reports the exact rejected token; other errors do not', () async {
    final rejected = <String>[];
    var status = 401;
    final service = ApiService(
      baseUrl: 'https://api.example.invalid',
      accessToken: () async => 'token-a',
      onSessionRejected: (token) async => rejected.add(token),
      client: MockClient((_) async => body({'detail': 'x'}, status)),
    );
    await expectLater(
      service.request('GET', '/api/cart'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.status, 'status', 401)
            .having(
              (e) => e.message,
              'message',
              contains('Sesiunea a expirat'),
            ),
      ),
    );
    expect(rejected, ['token-a']);
    for (status in [403, 404, 409, 422, 429, 500, 503]) {
      await expectLater(
        service.request('GET', '/api/cart'),
        throwsA(isA<ApiException>()),
      );
    }
    expect(rejected, ['token-a']);
    service.close();
  });

  test('A missing local session never reports a rejected token', () async {
    final rejected = <String>[];
    final service = ApiService(
      baseUrl: 'https://api.example.invalid',
      accessToken: () async => null,
      onSessionRejected: (token) async => rejected.add(token),
      client: MockClient((_) async => throw StateError('must not send')),
    );
    await expectLater(
      service.request('GET', '/api/cart'),
      throwsA(isA<ApiException>()),
    );
    expect(rejected, isEmpty);
    service.close();
  });
}
