import 'dart:convert';
import 'dart:io';
import 'dart:async';  // Добавляем импорт для TimeoutException
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiClient {
  final String baseUrl = ApiConfig.baseUrl;

  // Увеличиваем таймауты для медленных соединений
  static const timeout = Duration(seconds: 30);
  
  final http.Client _client;
  
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  @override
  void dispose() {
    _client.close();
  }

  Future<bool> testConnection() async {
    try {
      print('Testing API connection...');
      print('Base URL: $baseUrl');
      
      final uri = Uri.parse('$baseUrl/api/ping');
      print('Request URI: $uri');
      
      final response = await _client.get(uri).timeout(
        timeout,
        onTimeout: () {
          print('Connection timeout');
          throw TimeoutException('Connection timeout after ${timeout.inSeconds} seconds');
        },
      );
      
      print('Connection test response code: ${response.statusCode}');
      print('Response headers: ${response.headers}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          print('Decoded response: $data');
          return true;
        } catch (e) {
          print('Failed to decode response: $e');
          return false;
        }
      } else {
        print('Unexpected status code: ${response.statusCode}');
        return false;
      }
    } on SocketException catch (e) {
      print('Socket error: ${e.message}');
      print('Address: ${e.address}');
      print('Port: ${e.port}');
      return false;
    } on TimeoutException catch (e) {
      print('Timeout error: $e');
      return false;
    } catch (e, stackTrace) {
      print('Connection test failed: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

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
    final url = Uri.parse('$baseUrl/api$path');
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
    final url = Uri.parse('$baseUrl/api$path');
    print('GET Request: $url');
    
    try {
      final response = await _client.get(url).timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException('Request timeout after ${timeout.inSeconds} seconds');
        },
      );
      
      print('Response status: ${response.statusCode}');
      print('Response headers: ${response.headers}');
      print('Response body: ${response.body}');
      
      return response;
    } on SocketException catch (e) {
      print('Network error: ${e.message}');
      rethrow;
    } on TimeoutException catch (e) {
      print('Timeout error: $e');
      rethrow;
    } catch (e) {
      print('Request failed: $e');
      rethrow;
    }
  }

  Future<http.Response> post(String path, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseUrl/api$path');
    print('POST Request: $url');
    print('Request body: ${jsonEncode(body)}');
    
    try {
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException('Request timeout after ${timeout.inSeconds} seconds');
        },
      );
      
      print('Response status: ${response.statusCode}');
      print('Response headers: ${response.headers}');
      print('Response body: ${response.body}');
      
      return response;
    } on TimeoutException catch (e) {
      print('Timeout error: $e');
      rethrow;
    } catch (e) {
      print('Request failed: $e');
      rethrow;
    }
  }

  Future<http.Response> put(String path, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseUrl/api$path');
    print('PUT Request: $url');
    print('Request body: ${jsonEncode(body)}');
    
    try {
      final response = await _client.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException('Request timeout after ${timeout.inSeconds} seconds');
        },
      );
      
      print('Response status: ${response.statusCode}');
      print('Response headers: ${response.headers}');
      print('Response body: ${response.body}');
      
      return response;
    } on TimeoutException catch (e) {
      print('Timeout error: $e');
      rethrow;
    } catch (e) {
      print('Request failed: $e');
      rethrow;
    }
  }

  Future<http.Response> delete(String path) async {
    final url = Uri.parse('$baseUrl/api$path');
    print('DELETE Request: $url');
    
    try {
      final response = await _client.delete(
        url,
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException('Request timeout after ${timeout.inSeconds} seconds');
        },
      );
      
      print('Response status: ${response.statusCode}');
      print('Response headers: ${response.headers}');
      print('Response body: ${response.body}');
      
      return response;
    } on TimeoutException catch (e) {
      print('Timeout error: $e');
      rethrow;
    } catch (e) {
      print('Request failed: $e');
      rethrow;
    }
  }
}