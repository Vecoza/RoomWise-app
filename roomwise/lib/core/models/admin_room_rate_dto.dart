class AdminRoomRateDto {
  final int id;
  final int roomTypeId;
  final DateTime startDate;
  final DateTime endDate;
  final double price;
  final String currency;

  const AdminRoomRateDto({
    required this.id,
    required this.roomTypeId,
    required this.startDate,
    required this.endDate,
    required this.price,
    required this.currency,
  });

  factory AdminRoomRateDto.fromJson(Map<String, dynamic> json) {
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

    return AdminRoomRateDto(
      id: _asInt(json['id']),
      roomTypeId: _asInt(json['roomTypeId']),
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      price: _asDouble(json['price']),
      currency: (json['currency'] ?? 'EUR').toString(),
    );
  }
}

class AdminRoomRateUpsertRequest {
  final int roomTypeId;
  final DateTime startDate;
  final DateTime endDate;
  final double price;
  final String currency;

  const AdminRoomRateUpsertRequest({
    required this.roomTypeId,
    required this.startDate,
    required this.endDate,
    required this.price,
    required this.currency,
  });

  Map<String, dynamic> toJson() => {
        'roomTypeId': roomTypeId,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'price': price,
        'currency': currency,
      };
}
