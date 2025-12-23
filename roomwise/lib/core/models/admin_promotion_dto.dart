class AdminPromotionDto {
  final int id;
  final int hotelId;
  final String title;
  final String? description;
  final double? discountPercent;
  final double? discountFixed;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? minNights;
  final bool isActive;

  const AdminPromotionDto({
    required this.id,
    required this.hotelId,
    required this.title,
    required this.description,
    required this.discountPercent,
    required this.discountFixed,
    required this.startDate,
    required this.endDate,
    required this.minNights,
    required this.isActive,
  });

  factory AdminPromotionDto.fromJson(Map<String, dynamic> json) {
    double? _asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    int? _asInt(dynamic v) {
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    DateTime? _asDate(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    return AdminPromotionDto(
      id: _asInt(json['id']) ?? 0,
      hotelId: _asInt(json['hotelId']) ?? 0,
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      discountPercent: _asDouble(json['discountPercent']),
      discountFixed: _asDouble(json['discountFixed']),
      startDate: _asDate(json['startDate']),
      endDate: _asDate(json['endDate']),
      minNights: _asInt(json['minNights']),
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

class AdminPromotionUpsertRequest {
  final String title;
  final String? description;
  final double? discountPercent;
  final double? discountFixed;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? minNights;
  final bool isActive;

  const AdminPromotionUpsertRequest({
    required this.title,
    this.description,
    this.discountPercent,
    this.discountFixed,
    this.startDate,
    this.endDate,
    this.minNights,
    required this.isActive,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'discountPercent': discountPercent,
        'discountFixed': discountFixed,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'minNights': minNights,
        'isActive': isActive,
      };
}
