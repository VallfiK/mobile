class Booking {
  final String id;
  final String cottageId;
  final DateTime startDate;
  final DateTime endDate;
  final String userId;
  final String status;
  final String guestName;
  final String guestPhone;
  final String guestEmail;
  final double totalCost;
  final String notes;

  Booking({
    required this.id,
    required this.cottageId,
    required this.startDate,
    required this.endDate,
    required this.userId,
    this.status = 'free',
    this.guestName = '',
    this.guestPhone = '',
    this.guestEmail = '',
    required this.totalCost,
    this.notes = '',
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] ?? '',
      cottageId: json['cottageId'] ?? '',
      startDate: DateTime.parse(json['checkIn'] ?? DateTime.now().toIso8601String()),
      endDate: DateTime.parse(json['checkOut'] ?? DateTime.now().toIso8601String()),
      userId: json['userId'] ?? '',
      status: json['status'] ?? 'free',
      guestName: json['guestName'] ?? '',
      guestPhone: json['guestPhone'] ?? '',
      guestEmail: json['guestEmail'] ?? '',
      totalCost: (json['totalCost'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cottageId': cottageId,
      'checkIn': startDate.toIso8601String(),
      'checkOut': endDate.toIso8601String(),
      'userId': userId,
      'status': status,
      'guestName': guestName,
      'guestPhone': guestPhone,
      'guestEmail': guestEmail,
      'totalCost': totalCost,
      'notes': notes,
    };
  }
}
