class AdminRoomTypeDto {
  final int id;
  final int hotelId;
  final String name;
  final int capacity;
  final double basePrice;
  final int stock;
  final String? bedType;
  final String currency;
  final bool isSmokingAllowed;

  const AdminRoomTypeDto({
    required this.id,
    required this.hotelId,
    required this.name,
    required this.capacity,
    required this.basePrice,
    required this.stock,
    required this.bedType,
    required this.currency,
    required this.isSmokingAllowed,
  });

  factory AdminRoomTypeDto.fromJson(Map<String, dynamic> json) {
    double _asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    int _asInt(dynamic v) {
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    return AdminRoomTypeDto(
      id: _asInt(json['id']),
      hotelId: _asInt(json['hotelId']),
      name: (json['name'] ?? '').toString(),
      capacity: _asInt(json['capacity']),
      basePrice: _asDouble(json['basePrice']),
      stock: _asInt(json['stock']),
      bedType: (json['bedType'] ?? '').toString().isEmpty
          ? null
          : (json['bedType'] ?? '').toString(),
      currency: (json['currency'] ?? 'EUR').toString(),
      isSmokingAllowed: json['isSmokingAllowed'] as bool? ?? false,
    );
  }
}

class AdminRoomTypeUpsertRequest {
  final String name;
  final int capacity;
  final double basePrice;
  final int stock;
  final String? bedType;
  final String currency;
  final bool isSmokingAllowed;

  const AdminRoomTypeUpsertRequest({
    required this.name,
    required this.capacity,
    required this.basePrice,
    required this.stock,
    this.bedType,
    required this.currency,
    required this.isSmokingAllowed,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'capacity': capacity,
        'basePrice': basePrice,
        'stock': stock,
        'bedType': bedType,
        'currency': currency,
        'isSmokingAllowed': isSmokingAllowed,
      };
}
