// Обновленный файл lib/models/booking.dart
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
  final double remainingAmount;
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
    this.remainingAmount = 0,
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
    
    // Парсим финансовые поля
    final totalCost = json['total_cost'] != null 
        ? double.tryParse(json['total_cost'].toString()) ?? 0.0 
        : json['totalCost'] != null
            ? double.tryParse(json['totalCost'].toString()) ?? 0.0
            : 0.0;

    final prepayment = json['prepayment'] != null 
        ? double.tryParse(json['prepayment'].toString()) ?? 0.0 
        : 0.0;

    final totalPaid = json['total_paid'] != null 
        ? double.tryParse(json['total_paid'].toString()) ?? 0.0 
        : json['totalPaid'] != null
            ? double.tryParse(json['totalPaid'].toString()) ?? 0.0
            : 0.0;

    final remainingAmount = json['remaining_amount'] != null 
        ? double.tryParse(json['remaining_amount'].toString()) ?? 0.0 
        : json['remainingAmount'] != null
            ? double.tryParse(json['remainingAmount'].toString()) ?? 0.0
            : totalCost - totalPaid;
    
    print('Booking.fromJson - ID: $id');
    print('  Raw startDate: $startDateValue -> Parsed: $startDate');
    print('  Raw endDate: $endDateValue -> Parsed: $endDate');
    print('  Payment info: totalCost=$totalCost, prepayment=$prepayment, totalPaid=$totalPaid, remaining=$remainingAmount');
    
    return Booking(
      id: id,
      cottageId: json['cottage_id']?.toString() ?? json['cottageId']?.toString() ?? '',
      startDate: startDate,
      endDate: endDate,
      guests: json['guests'] ?? 1,
      status: json['status'] ?? 'booked',
      guestName: json['guest_name']?.toString() ?? json['guestName']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      totalCost: totalCost,
      prepayment: prepayment,
      totalPaid: totalPaid,
      remainingAmount: remainingAmount,
      tariffId: json['tariff_id']?.toString() ?? json['tariffId']?.toString() ?? '1',
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
      'prepayment': prepayment,
      'totalPaid': totalPaid,
      'remainingAmount': remainingAmount,
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
    double? remainingAmount,
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
      remainingAmount: remainingAmount ?? this.remainingAmount,
      tariffId: tariffId ?? this.tariffId,
    );
  }

  // Вспомогательные методы для работы с платежами
  bool get isFullyPaid => remainingAmount <= 0;
  bool get hasDeposit => prepayment > 0;
  double get unpaidAmount => totalCost - totalPaid;
  
  // Процент оплаченной суммы
  double get paidPercentage => totalCost > 0 ? (totalPaid / totalCost) * 100 : 0;
}