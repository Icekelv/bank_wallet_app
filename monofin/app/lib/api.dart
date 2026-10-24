import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';

class ApiException implements Exception {
  final String message;
  final int status;
  const ApiException(this.message, [this.status = 0]);

  bool get unauthorized => status == 401 || status == 403;

  @override
  String toString() => message;
}

/// Talks to the PHP backend. Every endpoint returns {"ok": bool, ...}.
class Api {
  String? token;

  Uri _uri(String endpoint, [Map<String, String>? query]) {
    final base = apiBaseUrl.endsWith('/') ? apiBaseUrl.substring(0, apiBaseUrl.length - 1) : apiBaseUrl;
    return Uri.parse('$base/api/$endpoint.php').replace(queryParameters: query);
  }

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (token != null) 'X-Auth-Token': token!,
      };

  Future<Map<String, dynamic>> get(String endpoint, [Map<String, String>? query]) {
    return _send(() => http.get(_uri(endpoint, query), headers: _headers));
  }

  Future<Map<String, dynamic>> post(String endpoint, [Map<String, dynamic>? body]) {
    return _send(() => http.post(_uri(endpoint), headers: _headers, body: jsonEncode(body ?? {})));
  }

  Future<Map<String, dynamic>> _send(Future<http.Response> Function() call) async {
    http.Response res;
    try {
      res = await call().timeout(const Duration(seconds: 20));
    } on SocketException {
      throw const ApiException('No internet connection.');
    } on TimeoutException {
      throw const ApiException('The server took too long to respond.');
    } on http.ClientException {
      throw const ApiException('Could not reach the server.');
    }

    Map<String, dynamic> data;
    try {
      data = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    } catch (_) {
      throw ApiException('Unexpected server response (${res.statusCode}).', res.statusCode);
    }
    if (data['ok'] != true) {
      throw ApiException((data['error'] ?? 'Something went wrong.').toString(), res.statusCode);
    }
    return data;
  }
}
