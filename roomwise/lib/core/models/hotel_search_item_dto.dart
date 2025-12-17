import 'package:roomwise/core/models/tag_dto.dart';

class HotelSearchItemDto {
  final int id;
  final String name;
  final String city;
  final double fromPrice;
  final double rating;
  final String? thumbnailUrl;
  final double? promotionPrice;
  final double? promotionDiscountPercent;
  final double? promotionDiscountFixed;
  final DateTime? promotionEndDate;
  final String? promotionTitle;
  final String currency;
  final bool hasAvailability;
  final List<TagDto> tags;
  final int reviewCount;

  HotelSearchItemDto({
    required this.id,
    required this.name,
    required this.city,
    required this.fromPrice,
    required this.rating,
    required this.hasAvailability,
    this.reviewCount = 0,
    this.promotionPrice,
    this.promotionDiscountPercent,
    this.promotionDiscountFixed,
    this.promotionEndDate,
    this.promotionTitle,
    this.currency = 'EUR',
    this.thumbnailUrl,
    this.tags = const [],
  });

  factory HotelSearchItemDto.fromJson(Map<String, dynamic> json) {
    final tagsJson = json['tags'] as List<dynamic>? ?? const [];
    final rawId = json['id'];
    final parsedId =
        rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');

    return HotelSearchItemDto(
      id: parsedId ?? 0,
      name: json['name'] as String,
      city: json['city'] as String? ?? '',
      fromPrice: (json['fromPrice'] as num?)?.toDouble() ?? 0.0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      promotionPrice: (json['promotionPrice'] as num?)?.toDouble(),
      promotionDiscountPercent:
          (json['promotionDiscountPercent'] as num?)?.toDouble(),
      promotionDiscountFixed:
          (json['promotionDiscountFixed'] as num?)?.toDouble(),
      promotionEndDate: json['promotionEndDate'] != null
          ? DateTime.tryParse(json['promotionEndDate'].toString())
          : null,
      promotionTitle: json['promotionTitle'] as String?,
      currency: json['currency'] as String? ?? 'EUR',
      reviewCount: (json['reviewCount'] as num? ??
              json['reviewsCount'] as num? ??
              json['ratingsCount'] as num?)
          ?.toInt() ??
          0,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      hasAvailability: json['hasAvailability'] as bool? ?? true,
      tags: tagsJson
          .map((e) => TagDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
