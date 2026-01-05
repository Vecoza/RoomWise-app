class AdminArrivalDto {
  final int reservationId;
  final String guestFirstName;
  final String guestLastName;
  final int roomTypeId;
  final String roomTypeName;
  final int guests;
  final double roomTotal;
  final String currency;
  final DateTime checkIn;

  const AdminArrivalDto({
    required this.reservationId,
    required this.guestFirstName,
    required this.guestLastName,
    required this.roomTypeId,
    required this.roomTypeName,
    required this.guests,
    required this.roomTotal,
    required this.currency,
    required this.checkIn,
  });

  factory AdminArrivalDto.fromJson(Map<String, dynamic> json) {
    int _asInt(dynamic v) {
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    double _asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    return AdminArrivalDto(
      reservationId: _asInt(json['reservationId']),
      guestFirstName: (json['guestFirstName'] ?? '').toString(),
      guestLastName: (json['guestLastName'] ?? '').toString(),
      roomTypeId: _asInt(json['roomTypeId']),
      roomTypeName: (json['roomTypeName'] ?? '').toString(),
      guests: _asInt(json['guests']),
      roomTotal: _asDouble(json['roomTotal']),
      currency: (json['currency'] ?? 'EUR').toString(),
      checkIn: DateTime.parse(json['checkIn'] as String),
    );
  }
}
