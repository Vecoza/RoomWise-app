class GuestBookingListItemDto {
  final String? publicId;
  final int? hotelId;
  final int id;
  final String hotelName;
  final String city;
  final String? thumbnailUrl;
  final DateTime checkIn;
  final DateTime checkOut;
  final int guests;
  final String status;
  final String roomTypeName;
  final double total;
  final String currency;

  final bool hasReview;

  GuestBookingListItemDto({
    this.publicId,
    this.hotelId,
    required this.id,
    required this.hotelName,
    required this.city,
    this.thumbnailUrl,
    required this.checkIn,
    required this.checkOut,
    required this.guests,
    required this.status,
    required this.roomTypeName,
    required this.total,
    required this.currency,
    required this.hasReview,
  });

  factory GuestBookingListItemDto.fromJson(Map<String, dynamic> json) {
    return GuestBookingListItemDto(
      publicId: json['publicId'] as String?,
      hotelId: json['hotelId'] as int?,
      id: json['id'] as int,
      hotelName: json['hotelName'] as String? ?? '',
      city: json['city'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String?,
      checkIn:
          DateTime.tryParse(json['checkIn'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      checkOut:
          DateTime.tryParse(json['checkOut'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      guests: (json['guests'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'Pending',
      roomTypeName:
          json['roomTypeName'] as String? ?? json['roomType'] as String? ?? '',
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? '',
      hasReview: json['hasReview'] as bool? ?? false,
    );
  }
}
