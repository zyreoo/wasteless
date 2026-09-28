import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, {this.status});
  final String message;
  final int? status;
  @override
  String toString() => message;
}

class ApiService {
  ApiService({
    required this.baseUrl,
    required this.accessToken,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();
  final String baseUrl;
  final Future<String?> Function() accessToken;
  final http.Client _client;
  final Duration timeout;

  Future<dynamic> request(
    String method,
    String path, {
    Object? body,
    String? idempotencyKey,
  }) async {
    final token = await accessToken();
    if (token == null) {
      throw const ApiException(
        'Autentifică-te pentru a continua.',
        status: 401,
      );
    }
    try {
      final request = http.Request(
        method,
        Uri.parse('${baseUrl.replaceFirst(RegExp(r'/$'), '')}$path'),
      );
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });
      if (idempotencyKey != null) {
        request.headers['Idempotency-Key'] = idempotencyKey;
      }
      if (body != null) request.body = jsonEncode(body);
      final response = await (() async => http.Response.fromStream(
        await _client.send(request),
      ))().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = switch (response.statusCode) {
          401 => 'Sesiunea a expirat. Autentifică-te din nou.',
          403 => 'Nu ai acces la această acțiune.',
          404 => 'Elementul nu mai este disponibil.',
          409 => 'Datele s-au schimbat. Reîncarcă și încearcă din nou.',
          422 => 'Verifică datele introduse.',
          429 => 'Prea multe încercări. Revino în câteva momente.',
          _ => 'Serviciul nu este disponibil momentan. Încearcă din nou.',
        };
        throw ApiException(message, status: response.statusCode);
      }
      if (response.statusCode == 204) return null;
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on TimeoutException {
      throw const ApiException(
        'Conexiunea durează prea mult. Încearcă din nou.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Nu ne putem conecta. Verifică conexiunea la internet.',
      );
    } on FormatException {
      throw const ApiException(
        'Răspunsul serviciului nu poate fi citit. Încearcă din nou.',
      );
    }
  }

  void close() => _client.close();
}
