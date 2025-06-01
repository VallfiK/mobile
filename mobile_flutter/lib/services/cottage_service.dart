import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/cottage.dart';
import 'api_client.dart';

class CottageService {
  final ApiClient _apiClient;

  CottageService(this._apiClient);

  Future<List<Cottage>> getCottages() async {
    final response = await _apiClient.get('/cottages');
    
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Cottage.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load cottages');
    }
  }

  Future<Cottage> getCottage(String id) async {
    final response = await _apiClient.get('/cottages/$id');
    
    if (response.statusCode == 200) {
      return Cottage.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load cottage');
    }
  }

  Future<List<DateTime>> getAvailableDates(String cottageId) async {
    final response = await _apiClient.get('/cottages/$cottageId/available-dates');
    
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((dateStr) => DateTime.parse(dateStr)).toList();
    } else {
      throw Exception('Failed to load available dates');
    }
  }

  Future<Cottage> createCottage(Cottage cottage) async {
    final response = await _apiClient.post(
      '/cottages',
      cottage.toJson(),
    );
    
    if (response.statusCode == 201) {
      return Cottage.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create cottage');
    }
  }

  Future<Cottage> updateCottage(Cottage cottage) async {
    final response = await _apiClient.put(
      '/cottages/${cottage.id}',
      cottage.toJson(),
    );
    
    if (response.statusCode == 200) {
      return Cottage.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update cottage');
    }
  }

  Future<void> deleteCottage(String id) async {
    final response = await _apiClient.delete('/cottages/$id');
    
    if (response.statusCode != 204) {
      throw Exception('Failed to delete cottage');
    }
  }
}
