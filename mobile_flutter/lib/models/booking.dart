class Booking {
  final String id;
  final String cottageId;
  final DateTime startDate;
  final DateTime endDate;
  final int guests;
  final String userId;
  final String status;
  final String guestName;
  final String phone;
  final String email;

  Booking({
    required this.id,
    required this.cottageId,
    required this.startDate,
    required this.endDate,
    required this.guests,
    required this.userId,
    this.status = 'free',
    this.guestName = '',
    this.phone = '',
    this.email = '',
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] ?? '',
      cottageId: json['cottageId'] ?? '',
      startDate: DateTime.parse(json['startDate'] ?? DateTime.now().toIso8601String()),
      endDate: DateTime.parse(json['endDate'] ?? DateTime.now().toIso8601String()),
      guests: json['guests'] ?? 0,
      userId: json['userId'] ?? '',
      status: json['status'] ?? 'free',
      guestName: json['guestName'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cottageId': cottageId,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'guests': guests,
      'userId': userId,
      'status': status,
      'guestName': guestName,
      'phone': phone,
      'email': email,
    };
  }
}
