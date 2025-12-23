class AdminReservationSummaryDto {
  final int totalReservations;
  final int totalNights;
  final double totalRevenue;
  final List<AdminStatusBreakdown> statusBreakdown;

  const AdminReservationSummaryDto({
    required this.totalReservations,
    required this.totalNights,
    required this.totalRevenue,
    required this.statusBreakdown,
  });

  factory AdminReservationSummaryDto.fromJson(Map<String, dynamic> json) {
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

    return AdminReservationSummaryDto(
      totalReservations: _asInt(json['totalReservations']),
      totalNights: _asInt(json['totalNights']),
      totalRevenue: _asDouble(json['totalRevenue']),
      statusBreakdown: (json['statusBreakdown'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AdminStatusBreakdown.fromJson)
          .toList(),
    );
  }
}

class AdminStatusBreakdown {
  final String status;
  final int count;

  const AdminStatusBreakdown({required this.status, required this.count});

  factory AdminStatusBreakdown.fromJson(Map<String, dynamic> json) {
    int _asInt(dynamic v) {
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    return AdminStatusBreakdown(
      status: (json['status'] ?? '').toString(),
      count: _asInt(json['count']),
    );
  }
}
