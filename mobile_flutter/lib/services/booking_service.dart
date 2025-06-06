import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/booking.dart';
import '../models/tariff.dart';
import '../config/api_config.dart';
import 'api_client.dart';

class BookingService {
  final ApiClient _apiClient;
  final String baseUrl = ApiConfig.baseUrl;

  BookingService(this._apiClient);

  Future<List<Booking>> getUserBookings() async {
    try {
      print('Fetching user bookings...');
      final response = await _apiClient.get('/bookings/user');
      print('User bookings response: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Booking.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load bookings: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getUserBookings: $e');
      rethrow;
    }
  }

  Future<List<Booking>> getBookingsByCottage(String cottageId) async {
    try {
      print('Fetching bookings for cottage: $cottageId');
      final response = await _apiClient.get('/bookings/cottage/$cottageId');
      print('Cottage bookings response: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Booking.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load cottage bookings: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getBookingsByCottage: $e');
      rethrow;
    }
  }

  Future<List<Booking>> getBookingsByDate(String cottageId, DateTime date) async {
    try {
      // Преобразуем дату в UTC для отправки на сервер
      final utcDate = date.toUtc();
      final formattedDate = utcDate.toIso8601String().split('T')[0];
      
      final response = await _apiClient.get('/bookings/cottage/$cottageId/date/$formattedDate');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Booking.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load bookings for date: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getBookingsByDate: $e');
      rethrow;
    }
  }

  Future<List<Tariff>> getTariffs() async {
    try {
      print('Fetching tariffs...');
      final response = await _apiClient.get('/bookings/tariffs');
      print('Tariffs response: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Tariff.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load tariffs: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getTariffs: $e');
      rethrow;
    }
  }

  Future<Booking> createBooking(Booking booking) async {
    try {
      print('\n=== BOOKING CREATION DEBUG INFO ===');
      
      // Проверка наличия данных
      print('\nПроверка обязательных полей:');
      print('Cottage ID: "${booking.cottageId}" (${booking.cottageId.isEmpty ? 'ПУСТО!' : 'OK'})');
      print('Guest Name: "${booking.guestName}" (${booking.guestName.isEmpty ? 'ПУСТО!' : 'OK'})');
      print('Phone: "${booking.phone}" (${booking.phone.isEmpty ? 'ПУСТО!' : 'OK'})');
      print('Check-in date: "${booking.startDate.toIso8601String()}"');
      print('Check-out date: "${booking.endDate.toIso8601String()}"');
      print('Guests count: ${booking.guests}');
      print('Total Cost: ${booking.totalCost}');
      print('Tariff ID: "${booking.tariffId}" (${booking.tariffId.isEmpty ? 'ПУСТО!' : 'OK'})');

      final requestBody = booking.toJson();
      print('\nЗапрос на сервер (JSON):');
      final prettyJson = const JsonEncoder.withIndent('  ').convert(requestBody);
      print(prettyJson);

      final response = await _apiClient.post(
        '/bookings',
        requestBody,
      );

      print('\nОтвет сервера:');
      print('Статус: ${response.statusCode}');
      print('Заголовки: ${response.headers}');
      
      if (response.statusCode != 201) {
        print('\nДетали ошибки:');
        try {
          final errorData = jsonDecode(response.body);
          print('Сообщение: ${errorData['message']}');
          if (errorData['details'] != null) {
            print('Дополнительно: ${errorData['details']}');
          }
        } catch (e) {
          print('Тело ответа (raw): ${response.body}');
        }
      }
      
      print('\n=== КОНЕЦ ОТЛАДОЧНОЙ ИНФОРМАЦИИ ===\n');

      if (response.statusCode == 201) {
        return Booking.fromJson(jsonDecode(response.body));
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to create booking');
      }
    } catch (e) {
      print('Error in createBooking: $e');
      rethrow;
    }
  }

  Future<void> cancelBooking(String id) async {
    try {
      if (id.isEmpty) {
        throw Exception('ID бронирования не может быть пустым');
      }
      
      print('Cancelling booking with ID: $id');
      final response = await _apiClient.delete('/bookings/$id');
      print('Cancel booking response: ${response.statusCode}');
      print('Response headers: ${response.headers}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 404) {
        throw Exception('Бронирование не найдено. Возможно, оно уже было отменено.');
      } else if (response.statusCode != 204) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Не удалось отменить бронирование');
      }
    } catch (e) {
      print('Error in cancelBooking: $e');
      rethrow;
    }
  }

  Future<void> checkoutBooking(String bookingId) async {
    try {
      print('Completing booking: $bookingId');
      final response = await _apiClient.delete('/bookings/$bookingId/checkout');
      
      if (response.statusCode != 200) {
        throw Exception('Failed to complete booking: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in checkoutBooking: $e');
      rethrow;
    }
  }

  Future<Booking> updateBookingStatus(String bookingId, String status) async {
    try {
      print('Updating booking status: $bookingId to $status');
      final response = await _apiClient.put(
        '/bookings/$bookingId/status',
        {'status': status}
      );

      print('Update status response: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        return Booking.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to update booking status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in updateBookingStatus: $e');
      rethrow;
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

  Future<Tariff> createTariff({
    required String name,
    required double pricePerDay,
  }) async {
    try {
      final response = await _apiClient.post(
        '/bookings/tariffs',
        {
          'name': name,
          'pricePerDay': pricePerDay,
        },
      );

      if (response.statusCode == 201) {
        return Tariff.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to create tariff');
      }
    } catch (e) {
      throw Exception('Error creating tariff: $e');
    }
  }

  Future<Tariff> updateTariff({
    required String tariffId,
    required String name,
    required double pricePerDay,
  }) async {
    try {
      final response = await _apiClient.put(
        '/bookings/tariffs/$tariffId',
        {
          'name': name,
          'pricePerDay': pricePerDay,
        },
      );

      if (response.statusCode == 200) {
        return Tariff.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to update tariff');
      }
    } catch (e) {
      throw Exception('Error updating tariff: $e');
    }
  }

  Future<void> deleteTariff(String tariffId) async {
    try {
      final response = await _apiClient.delete('/bookings/tariffs/$tariffId');
      
      if (response.statusCode != 204) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Не удалось удалить тариф');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Ошибка при удалении тарифа: $e');
    }
  }
}
