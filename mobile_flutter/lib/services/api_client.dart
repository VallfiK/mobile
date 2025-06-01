import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String baseUrl = 'http://192.168.0.103:8080/api'; // Адрес вашего Go-бэкенда
  // Используем 10.0.2.2 для доступа к хосту из эмулятора Android
  
  final http.Client _client;
  
  ApiClient() : _client = http.Client();

  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<http.Response> _sendRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('$baseUrl$path');
    final authHeaders = await _getAuthHeaders();
    
    final requestHeaders = {
      'Content-Type': 'application/json',
      ...?headers,
      ...authHeaders,
    };

    final response = await _client.send(
      http.Request(method, url)
        ..headers.addAll(requestHeaders)
        ..body = body != null ? jsonEncode(body) : '',
    );

    return http.Response.fromStream(response);
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await getAuthToken();
    if (token != null) {
      return {'Authorization': 'Bearer $token'};
    }
    return {};
  }

  Future<http.Response> get(String path, {Map<String, String>? headers}) {
    return _sendRequest('GET', path, headers: headers);
  }

  Future<http.Response> post(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) {
    return _sendRequest('POST', path, body: body, headers: headers);
  }

  Future<http.Response> put(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) {
    return _sendRequest('PUT', path, body: body, headers: headers);
  }

  Future<http.Response> delete(String path, {Map<String, String>? headers}) {
    return _sendRequest('DELETE', path, headers: headers);
  }

  void dispose() {
    _client.close();
  }
}
