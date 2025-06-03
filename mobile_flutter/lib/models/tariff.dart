class Tariff {
  final String id;
  final String name;
  final double pricePerDay;

  Tariff({
    required this.id,
    required this.name,
    required this.pricePerDay,
  });

  factory Tariff.fromJson(Map<String, dynamic> json) {
    return Tariff(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      pricePerDay: (json['pricePerDay'] is num) 
          ? (json['pricePerDay'] as num).toDouble() 
          : 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'pricePerDay': pricePerDay,
    };
  }
} 