class AdminRoomAvailabilityDto {
  final int id;
  final int roomTypeId;
  final DateTime date;
  final int available;

  const AdminRoomAvailabilityDto({
    required this.id,
    required this.roomTypeId,
    required this.date,
    required this.available,
  });

  factory AdminRoomAvailabilityDto.fromJson(Map<String, dynamic> json) {
    int _asInt(dynamic v) {
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    return AdminRoomAvailabilityDto(
      id: _asInt(json['id']),
      roomTypeId: _asInt(json['roomTypeId']),
      date: DateTime.parse(json['date'] as String),
      available: _asInt(json['available']),
    );
  }
}

class AdminRoomAvailabilityUpsertRequest {
  final int roomTypeId;
  final DateTime date;
  final int available;

  const AdminRoomAvailabilityUpsertRequest({
    required this.roomTypeId,
    required this.date,
    required this.available,
  });

  Map<String, dynamic> toJson() => {
        'roomTypeId': roomTypeId,
        'date': date.toIso8601String(),
        'available': available,
      };
}
