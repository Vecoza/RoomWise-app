import 'package:roomwise/core/models/hotel_search_item_dto.dart';

class WishlistItemDto {
  final int id;
  final String userId;
  final int hotelId;
  final DateTime createdAt;
  final HotelSearchItemDto hotel;

  WishlistItemDto({
    required this.id,
    required this.userId,
    required this.hotelId,
    required this.createdAt,
    required this.hotel,
  });

  factory WishlistItemDto.fromJson(Map<String, dynamic> json) {
    final hotelJson = json['hotel'] as Map<String, dynamic>? ?? const {};
    final parsedId = _parseId(json['id']) ?? 0;
    final parsedHotelId =
        _parseId(json['hotelId']) ?? _parseId(hotelJson['id']) ?? 0;

    return WishlistItemDto(
      id: parsedId,
      userId: json['userId']?.toString() ?? '',
      hotelId: parsedHotelId,
      createdAt: _parseDate(json['createdAt']),
      hotel: HotelSearchItemDto.fromJson(
        Map<String, dynamic>.from(hotelJson),
      ),
    );
  }

  static int? _parseId(dynamic raw) {
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  static DateTime _parseDate(dynamic raw) {
    if (raw is DateTime) return raw;
    final parsed = DateTime.tryParse(raw?.toString() ?? '');
    return parsed ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
}
