import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/booking.dart';
import 'api_client.dart';

class BookingService {
  final ApiClient _apiClient;

  BookingService(this._apiClient);

  Future<List<Booking>> getUserBookings() async {
    final response = await _apiClient.get('/bookings/user');
    
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Booking.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load bookings');
    }
  }

  Future<List<Booking>> getBookingsByCottage(String cottageId) async {
    final response = await _apiClient.get('/bookings/cottage/$cottageId');
    
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Booking.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load bookings');
    }
  }

    Future<Booking> createBooking(Booking booking) async {
    final response = await _apiClient.post(
      '/bookings',
      {
        'startDate': booking.startDate.toIso8601String(),
        'endDate': booking.endDate.toIso8601String(),
        'cottageId': booking.cottageId,
        'guestName': booking.guestName,
        'phone': booking.phone,
        'email': booking.email,
        'guests': booking.guests,
        'userId': booking.userId,
      },
    );
    
    if (response.statusCode == 201) {
      return Booking.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create booking');
    }
  }

  Future<void> cancelBooking(String id) async {
    final response = await _apiClient.delete('/bookings/$id');
    
    if (response.statusCode != 204) {
      throw Exception('Failed to cancel booking');
    }
  }

  Future<List<DateTime>> getAvailableDates(String cottageId) async {
    final response = await _apiClient.get('/bookings/cottage/$cottageId/available-dates');
    
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((dateStr) => DateTime.parse(dateStr)).toList();
    } else {
      throw Exception('Failed to load available dates');
    }
  }
}
