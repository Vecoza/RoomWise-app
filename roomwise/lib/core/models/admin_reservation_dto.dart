class AdminReservationDto {
  final int id;
  final String publicId;
  final int hotelId;
  final int? roomTypeId;
  final String? confirmationNumber;
  final DateTime checkIn;
  final DateTime checkOut;
  final int guests;
  final String status;
  final double subtotal;
  final double total;
  final double amountPaid;
  final String currency;
  final DateTime createdAt;
  final List<AdminReservationAddOnDto> addOns;

  const AdminReservationDto({
    required this.id,
    required this.publicId,
    required this.hotelId,
    required this.roomTypeId,
    required this.confirmationNumber,
    required this.checkIn,
    required this.checkOut,
    required this.guests,
    required this.status,
    required this.subtotal,
    required this.total,
    required this.amountPaid,
    required this.currency,
    required this.createdAt,
    required this.addOns,
  });

  factory AdminReservationDto.fromJson(Map<String, dynamic> json) {
    double _asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    return AdminReservationDto(
      id: json['id'] as int,
      publicId: (json['publicId'] ?? '').toString(),
      hotelId: json['hotelId'] as int? ?? 0,
      roomTypeId: json['roomTypeId'] as int?,
      confirmationNumber: json['confirmationNumber']?.toString(),
      checkIn: DateTime.parse(json['checkIn'] as String),
      checkOut: DateTime.parse(json['checkOut'] as String),
      guests: json['guests'] as int? ?? 1,
      status: (json['status'] ?? '').toString(),
      subtotal: _asDouble(json['subtotal']),
      total: _asDouble(json['total']),
      amountPaid: _asDouble(json['amountPaid']),
      currency: (json['currency'] ?? 'EUR').toString(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      addOns: (json['addOns'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AdminReservationAddOnDto.fromJson)
          .toList(),
    );
  }
}

class AdminReservationAddOnDto {
  final int id;
  final String name;
  final double price;
  final String pricingModel;
  final String currency;

  const AdminReservationAddOnDto({
    required this.id,
    required this.name,
    required this.price,
    required this.pricingModel,
    required this.currency,
  });

  factory AdminReservationAddOnDto.fromJson(Map<String, dynamic> json) {
    double _asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    return AdminReservationAddOnDto(
      id: json['id'] as int? ?? 0,
      name: (json['name'] ?? '').toString(),
      price: _asDouble(json['price']),
      pricingModel: (json['pricingModel'] ?? '').toString(),
      currency: (json['currency'] ?? 'EUR').toString(),
    );
  }
}
