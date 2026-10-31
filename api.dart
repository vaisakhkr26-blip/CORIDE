import 'dart:convert';

import 'package:http/http.dart' as http;

/// Address of the backend. Change at build time:
///   flutter run --dart-define=API_URL=http://192.168.1.10:3000
/// 10.0.2.2 is how the Android emulator reaches the computer it runs on.
const String kApiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:3000');

typedef Json = Map<String, dynamic>;

List<Json> listOf(dynamic x) => (x as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

class ApiException implements Exception {
  final int status;
  final String code;
  final String message;
  ApiException(this.status, this.code, this.message);

  @override
  String toString() => message;
}

class Api {
  String? token;

  Future<Json> _send(String method, String path, {Json? body, Map<String, String>? query}) async {
    var uri = Uri.parse('$kApiUrl$path');
    if (query != null && query.isNotEmpty) uri = uri.replace(queryParameters: query);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    http.Response res;
    try {
      final timeout = const Duration(seconds: 20);
      switch (method) {
        case 'POST':
          res = await http.post(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(timeout);
          break;
        case 'PUT':
          res = await http.put(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(timeout);
          break;
        default:
          res = await http.get(uri, headers: headers).timeout(timeout);
      }
    } catch (_) {
      throw ApiException(0, 'network', 'Cannot reach the server. Check your internet connection and try again.');
    }

    dynamic data;
    if (res.body.isNotEmpty) {
      try {
        data = jsonDecode(utf8.decode(res.bodyBytes));
      } catch (_) {
        data = null;
      }
    }
    if (res.statusCode >= 400) {
      final err = (data is Map && data['error'] is Map) ? data['error'] as Map : const {};
      throw ApiException(
        res.statusCode,
        (err['code'] ?? 'error').toString(),
        (err['message'] ?? 'Something went wrong. Please try again.').toString(),
      );
    }
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  Future<Json> get(String path, {Map<String, String>? query}) => _send('GET', path, query: query);
  Future<Json> post(String path, [Json? body]) => _send('POST', path, body: body);
  Future<Json> put(String path, Json body) => _send('PUT', path, body: body);
}
