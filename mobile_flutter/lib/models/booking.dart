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
  final double prepayment;
  final double totalPaid;
  final double remaining;
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
    this.prepayment = 0,
    this.totalPaid = 0,
    this.remaining = 0,
    required this.tariffId,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    // Пытаемся получить ID из разных возможных полей
    final id = (json['id'] ?? json['booking_id'])?.toString() ?? '';
    
    // Парсим даты из строк (теперь ожидаем только даты без времени)
    DateTime parseDate(dynamic dateValue) {
      if (dateValue == null) return DateTime.now();
      
      if (dateValue is String) {
        try {
          // Если это ISO строка с временем, парсим её
          if (dateValue.contains('T')) {
            return DateTime.parse(dateValue);
          }
          // Если это просто дата в формате YYYY-MM-DD, добавляем время 00:00:00
          if (dateValue.length == 10 && dateValue.contains('-')) {
            return DateTime.parse(dateValue + 'T00:00:00.000');
          }
          // Пытаемся парсить как есть
          return DateTime.parse(dateValue);
        } catch (e) {
          print('Error parsing date: $dateValue, error: $e');
          return DateTime.now();
        }
      }
      
      if (dateValue is DateTime) {
        return dateValue;
      }
      
      return DateTime.now();
    }
    
    final startDateValue = json['check_in_date'] ?? json['startDate'];
    final endDateValue = json['check_out_date'] ?? json['endDate'];
    
    final startDate = parseDate(startDateValue);
    final endDate = parseDate(endDateValue);
    
    print('Booking.fromJson - ID: $id');
    print('  Raw startDate: $startDateValue -> Parsed: $startDate');
    print('  Raw endDate: $endDateValue -> Parsed: $endDate');
    
    return Booking(
      id: id,
      cottageId: json['cottageId']?.toString() ?? '',
      startDate: parseDate(json['startDate']),
      endDate: parseDate(json['endDate']),
      guests: json['guests']?.toInt() ?? 1,
      status: json['status'] ?? 'pending',
      guestName: json['guestName'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      notes: json['notes'] ?? '',
      totalCost: double.tryParse(json['totalCost']?.toString() ?? '0') ?? 0,
      prepayment: double.tryParse(json['prepayment']?.toString() ?? '0') ?? 0,
      totalPaid: double.tryParse(json['totalPaid']?.toString() ?? '0') ?? 0,
      remaining: double.tryParse(json['remaining']?.toString() ?? '0') ?? 0,
      tariffId: json['tariffId']?.toString() ?? '',
    );
  }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cottageId': cottageId,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'guests': guests,
      'status': status,
      'guestName': guestName,
      'phone': phone,
      'email': email,
      'notes': notes,
      'totalCost': totalCost,
      'prepayment': prepayment,
      'totalPaid': totalPaid,
      'remaining': remaining,
      'tariffId': tariffId,
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
    double? prepayment,
    double? totalPaid,
    double? remaining,
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
      prepayment: prepayment ?? this.prepayment,
      totalPaid: totalPaid ?? this.totalPaid,
      remaining: remaining ?? this.remaining,
      tariffId: tariffId ?? this.tariffId,
    );
  }
}  // Закрывающая фигурная скобка класса Booking
}