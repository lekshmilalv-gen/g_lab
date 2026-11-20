import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

/// Shared HTTP configuration for the app's backend requests.
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  static const String _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  // For USB-connected physical phones, forward the backend port with
  // `adb reverse tcp:8001 tcp:8001` and use the device's localhost.
  static String get baseUrl => _configuredBaseUrl.isNotEmpty
      ? _configuredBaseUrl
      : _usbForwardedBaseUrl;

  static const String _usbForwardedBaseUrl = 'http://127.0.0.1:8001';

  static const Duration _timeout = Duration(seconds: 15);

  Future<Map<String, dynamic>> getJson(String path) async {
    final response = await http
        .get(_uri(path), headers: _headers())
        .timeout(_timeout);
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    bool authenticated = true,
  }) async {
    final response = await http
        .post(
          _uri(path),
          headers: _headers(authenticated: authenticated),
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http
        .patch(_uri(path), headers: _headers(), body: jsonEncode(body))
        .timeout(_timeout);
    return _decodeObject(response);
  }

  Future<List<dynamic>> getJsonList(String path) async {
    final response = await http
        .get(_uri(path), headers: _headers())
        .timeout(_timeout);
    final dynamic body = _decode(response);
    if (body is List<dynamic>) return body;
    if (body is Map<String, dynamic> && body['results'] is List<dynamic>) {
      return body['results'] as List<dynamic>;
    }
    throw const ApiException('The server returned an unexpected response.');
  }

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> _headers({bool authenticated = true}) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = AuthService.instance.accessToken;
    if (authenticated && token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    final dynamic value = _decode(response);
    if (value is Map<String, dynamic>) return value;
    throw const ApiException('The server returned an unexpected response.');
  }

  dynamic _decode(http.Response response) {
    dynamic value;
    try {
      value = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
    } on FormatException {
      value = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = value is Map<String, dynamic>
          ? value['detail'] ?? value['message'] ?? value['error']
          : null;
      throw ApiException(
        detail is String && detail.isNotEmpty
            ? detail
            : 'Server request failed (${response.statusCode}).',
      );
    }
    if (value == null) {
      throw const ApiException('The server returned an invalid response.');
    }
    return value;
  }
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
