class AdminRoomTypeAvailabilityDto {
  final int roomTypeId;
  final String roomTypeName;
  final int stock;
  final int reserved;
  final int available;
  final String currency;
  final DateTime date;

  const AdminRoomTypeAvailabilityDto({
    required this.roomTypeId,
    required this.roomTypeName,
    required this.stock,
    required this.reserved,
    required this.available,
    required this.currency,
    required this.date,
  });

  factory AdminRoomTypeAvailabilityDto.fromJson(Map<String, dynamic> json) {
    int _asInt(dynamic v) {
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    return AdminRoomTypeAvailabilityDto(
      roomTypeId: _asInt(json['roomTypeId']),
      roomTypeName: (json['roomTypeName'] ?? '').toString(),
      stock: _asInt(json['stock']),
      reserved: _asInt(json['reserved']),
      available: _asInt(json['available']),
      currency: (json['currency'] ?? 'EUR').toString(),
      date: DateTime.parse(json['date'] as String),
    );
  }
}
