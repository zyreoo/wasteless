import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, {this.status, this.retryAfter});
  final String message;
  final int? status;
  final Duration? retryAfter;
  @override
  String toString() => message;
}

/// Bearer token plus the means to tell auth which token the server rejected.
typedef AccessToken = Future<String?> Function();
typedef SessionRejected = Future<void> Function(String token);

class ApiService {
  ApiService({
    required this.baseUrl,
    required this.accessToken,
    this.onSessionRejected,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();
  final String baseUrl;
  final AccessToken accessToken;

  /// Called once per rejected request with the exact token that was refused,
  /// so a late 401 from an old session can never sign out a newer one.
  final SessionRejected? onSessionRejected;
  final http.Client _client;
  final Duration timeout;

  Future<dynamic> request(
    String method,
    String path, {
    Object? body,
    String? idempotencyKey,
    List<int>? bytes,
    String? contentType,
  }) async {
    final token = await accessToken();
    if (token == null) {
      throw const ApiException(
        'Autentifică-te pentru a continua.',
        status: 401,
      );
    }
    final http.Response response;
    try {
      final request = http.Request(
        method,
        Uri.parse('${baseUrl.replaceFirst(RegExp(r'/$'), '')}$path'),
      );
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Content-Type': contentType ?? 'application/json',
      });
      if (idempotencyKey != null) {
        request.headers['Idempotency-Key'] = idempotencyKey;
      }
      if (bytes != null) {
        request.bodyBytes = bytes;
      } else if (body != null) {
        request.body = jsonEncode(body);
      }
      response = await (() async => http.Response.fromStream(
        await _client.send(request),
      ))().timeout(timeout);
    } on TimeoutException {
      throw const ApiException(
        'Conexiunea durează prea mult. Încearcă din nou.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Nu ne putem conecta. Verifică conexiunea la internet.',
      );
    }
    if (response.statusCode == 401) {
      // The API answers 401 only when Supabase no longer accepts the token.
      await onSessionRejected?.call(token);
      throw const ApiException(
        'Sesiunea a expirat. Autentifică-te din nou.',
        status: 401,
      );
    }
    if (response.statusCode == 429) {
      final wait = retryAfter(response.headers['retry-after']);
      throw ApiException(
        wait == null
            ? 'Prea multe solicitări. Încearcă din nou în câteva secunde.'
            : 'Prea multe solicitări. Încearcă din nou în ${wait.inSeconds} ${wait.inSeconds == 1 ? 'secundă' : 'secunde'}.',
        status: 429,
        retryAfter: wait,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        safeDetail(response) ?? fallbackMessage(response.statusCode),
        status: response.statusCode,
      );
    }
    if (response.statusCode == 204 || response.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const ApiException(
        'Răspunsul serviciului nu poate fi citit. Încearcă din nou.',
      );
    }
  }

  static String fallbackMessage(int status) => switch (status) {
    403 => 'Nu ai acces la această acțiune.',
    404 => 'Elementul nu mai este disponibil.',
    409 => 'Datele s-au schimbat. Reîncarcă și încearcă din nou.',
    422 => 'Verifică datele introduse.',
    _ => 'Serviciul nu este disponibil momentan. Încearcă din nou.',
  };

  /// Framework defaults that are not written for customers.
  static const _genericDetails = {
    'not found',
    'method not allowed',
    'unauthorized',
    'forbidden',
    'internal server error',
    'bad request',
    'service unavailable',
  };
  static final _technical = RegExp(
    r'traceback|exception|error:|sql|select\s|insert\s|update\s|delete\s|'
    r'postgres|postgrest|supabase|jwt|bearer|eyJ|https?://|\bat\s+\S+\.(py|dart):|'
    r'violates|constraint|duplicate key|permission denied|relation\s|column\s|'
    r'[{}<>\[\]\\"]',
    caseSensitive: false,
  );

  /// Returns the API's customer-facing `detail` string, or null when the body
  /// is missing, malformed, structured (validation lists) or looks technical.
  static String? safeDetail(http.Response response) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final detail = decoded['detail'];
    if (detail is! String) return null;
    final text = detail.trim();
    if (text.isEmpty ||
        text.length > 200 ||
        text.contains('\n') ||
        _genericDetails.contains(text.toLowerCase()) ||
        _technical.hasMatch(text)) {
      return null;
    }
    return text;
  }

  /// Accepts delta-seconds only (what the API sends), bounded to an hour.
  static Duration? retryAfter(String? header) {
    final seconds = int.tryParse(header?.trim() ?? '');
    if (seconds == null || seconds < 1 || seconds > 3600) return null;
    return Duration(seconds: seconds);
  }

  void close() => _client.close();
}
