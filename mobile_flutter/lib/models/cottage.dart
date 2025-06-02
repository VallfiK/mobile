class Cottage {
  final String id;
  final String name;
  final String description;
  final double price;
  final List<String> images;
  final int capacity;

  Cottage({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.images,
    required this.capacity,
  });

  factory Cottage.fromJson(Map<String, dynamic> json) {
    return Cottage(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      images: json['images'] != null 
          ? List<String>.from(json['images']) 
          : <String>[],
      capacity: json['capacity'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'images': images,
      'capacity': capacity,
    };
  }
}