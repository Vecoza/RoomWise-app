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

class AdminOverviewStatsDto {
  final double totalRevenue;
  final int totalReservations;
  final int totalUsers;
  final double avgStayLengthNights;
  final double occupancyRateLast30Days;

  const AdminOverviewStatsDto({
    required this.totalRevenue,
    required this.totalReservations,
    required this.totalUsers,
    required this.avgStayLengthNights,
    required this.occupancyRateLast30Days,
  });

  factory AdminOverviewStatsDto.fromJson(Map<String, dynamic> json) {
    final bookings = _asInt(json['totalBookings']);
    final reservations = _asInt(json['totalReservations']);

    return AdminOverviewStatsDto(
      totalRevenue: _asDouble(json['totalRevenue']),
      totalReservations: reservations > 0 ? reservations : bookings,
      totalUsers: _asInt(json['totalUsers']),
      avgStayLengthNights: _asDouble(json['avgStayLengthNights']),
      occupancyRateLast30Days: _asDouble(json['occupancyRateLast30Days']),
    );
  }

  double get earnings => totalRevenue * 0.72;
  static const empty = AdminOverviewStatsDto(
    totalRevenue: 0,
    totalReservations: 0,
    totalUsers: 0,
    avgStayLengthNights: 0,
    occupancyRateLast30Days: 0,
  );
}

class MonthlyRevenuePointDto {
  final int month;
  final double revenue;

  const MonthlyRevenuePointDto({required this.month, required this.revenue});

  factory MonthlyRevenuePointDto.fromJson(Map<String, dynamic> json) {
    return MonthlyRevenuePointDto(
      month: _asInt(json['month']).clamp(1, 12),
      revenue: _asDouble(json['revenue']),
    );
  }
}

class AdminTopHotelDto {
  final int hotelId;
  final String hotelName;
  final double rating;
  final int reservationsCount;
  final double revenue;

  const AdminTopHotelDto({
    required this.hotelId,
    required this.hotelName,
    required this.rating,
    required this.reservationsCount,
    required this.revenue,
  });

  factory AdminTopHotelDto.fromJson(Map<String, dynamic> json) {
    return AdminTopHotelDto(
      hotelId: _asInt(json['hotelId']),
      hotelName: (json['hotelName'] ?? json['name'] ?? 'Hotel').toString(),
      rating: _asDouble(json['rating']),
      reservationsCount: _asInt(json['reservationsCount']),
      revenue: _asDouble(json['revenue']),
    );
  }
}

class AdminTopUserDto {
  final String userId;
  final String email;
  final String fullName;
  final int reservationsCount;
  final double revenue;

  const AdminTopUserDto({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.reservationsCount,
    required this.revenue,
  });

  factory AdminTopUserDto.fromJson(Map<String, dynamic> json) {
    return AdminTopUserDto(
      userId: (json['userId'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      fullName: (json['fullName'] ?? json['name'] ?? '').toString(),
      reservationsCount: _asInt(json['reservationsCount']),
      revenue: _asDouble(json['revenue']),
    );
  }
}
