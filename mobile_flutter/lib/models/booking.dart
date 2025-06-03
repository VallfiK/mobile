import 'package:intl/intl.dart';

class Booking {
  final String id;
  final String cottageId;
  final DateTime startDate;
  final DateTime endDate;
  final int guests;
  final String status;
  final String guestName;
  final String phone;
  final String email;
  final String notes;
  final double totalCost;
  final String tariffId;

  Booking({
    required this.id,
    required this.cottageId,
    required this.startDate,
    required this.endDate,
    required this.guests,
    required this.status,
    required this.guestName,
    required this.phone,
    required this.email,
    this.notes = '',
    this.totalCost = 0,
    required this.tariffId,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    // Пытаемся получить ID из разных возможных полей
    final id = (json['id'] ?? json['booking_id'])?.toString() ?? '';
    
    return Booking(
      id: id,
      cottageId: json['cottage_id']?.toString() ?? '',
      startDate: DateTime.parse(json['check_in_date'] ?? DateTime.now().toIso8601String()).toLocal(),
      endDate: DateTime.parse(json['check_out_date'] ?? DateTime.now().toIso8601String()).toLocal(),
      guests: json['guests'] ?? 1,
      status: json['status'] ?? 'booked',
      guestName: json['guest_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      totalCost: json['total_cost'] != null 
          ? double.tryParse(json['total_cost'].toString()) ?? 0.0 
          : 0.0,
      tariffId: json['tariff_id']?.toString() ?? '1',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cottageId': cottageId,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'guests': guests,
      'status': status,
      'guestName': guestName,
      'phone': phone,
      'email': email,
      'notes': notes,
      'tariffId': tariffId,
      'totalCost': totalCost,
    };
  }

  Booking copyWith({
    String? id,
    String? cottageId,
    DateTime? startDate,
    DateTime? endDate,
    int? guests,
    String? status,
    String? guestName,
    String? phone,
    String? email,
    String? notes,
    double? totalCost,
    String? tariffId,
  }) {
    return Booking(
      id: id ?? this.id,
      cottageId: cottageId ?? this.cottageId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      guests: guests ?? this.guests,
      status: status ?? this.status,
      guestName: guestName ?? this.guestName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      totalCost: totalCost ?? this.totalCost,
      tariffId: tariffId ?? this.tariffId,
    );
  }
}
