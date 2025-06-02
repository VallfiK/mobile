import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  // Для iOS симулятора и физических устройств используйте IP вашего компьютера
  static String get baseUrl {
    if (Platform.isAndroid) {
      // Для Android устройства
      return 'http://178.234.13.110:8080/api';
    } else if (Platform.isIOS) {
      // Для iOS симулятора используйте IP вашего компьютера
      return 'http://178.234.13.110:8080/api';
    } else {
      // Для веб и других платформ
      return 'http://178.234.13.110:8080/api';
    }
  }

  @override
  void dispose() {
    _client.close();
  }

  Future<bool> testConnection() async {
    try {
      final response = await _client.get(Uri.parse('${baseUrl}/apiping'));
      print('Connection test response: ${response.statusCode}');
      print('Response body: ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }

  final http.Client _client;
  
  ApiClient({http.Client? client}) : _client = client ?? http.Client();


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

    try {
      final response = await _client.send(
        http.Request(method, url)
          ..headers.addAll(requestHeaders)
          ..body = body != null ? jsonEncode(body) : '',
      );

      return http.Response.fromStream(response);
    } catch (e) {
      print('Network error: $e');
      rethrow;
    }
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await getAuthToken();
    if (token != null) {
      return {'Authorization': 'Bearer $token'};
    }
    return {};
  }

  Future<http.Response> get(String path) async {
    final url = Uri.parse('$baseUrl$path');
    print('GET $url');
    print('Full URL: ${url.toString()}');
    try {
      print('Sending request...');
      final response = await _client.get(url);
      print('Response received');
      print('Status code: ${response.statusCode}');
      print('Headers: ${response.headers}');
      print('Body: ${response.body}');
      return response;
    } catch (e) {
      print('Error occurred: $e');
      if (e is SocketException) {
        print('Socket error: ${e.message}');
      }
      rethrow;
    }
  }

  Future<http.Response> post(String path, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseUrl$path');
    print('POST $url');
    print('Body: ${jsonEncode(body)}');
    try {
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      return response;
    } catch (e) {
      print('Error: $e');
      rethrow;
    }
  }

  Future<http.Response> put(String path, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseUrl$path');
    print('PUT $url');
    print('Body: ${jsonEncode(body)}');
    try {
      final response = await _client.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      return response;
    } catch (e) {
      print('Error: $e');
      rethrow;
    }
  }

  Future<http.Response> delete(String path) async {
    final url = Uri.parse('$baseUrl$path');
    print('DELETE $url');
    try {
      final response = await _client.delete(url);
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      return response;
    } catch (e) {
      print('Error: $e');
      rethrow;
    }
  }
}