class Booking {
  final String id;
  final String cottageId;
  final DateTime startDate;
  final DateTime endDate;
  final int guests;
  final String userId;

  Booking({
    required this.id,
    required this.cottageId,
    required this.startDate,
    required this.endDate,
    required this.guests,
    required this.userId,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'],
      cottageId: json['cottageId'],
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      guests: json['guests'],
      userId: json['userId'],
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
    };
  }
}
