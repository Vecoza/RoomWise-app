import 'package:roomwise/core/models/tag_dto.dart';

class HotelSearchItemDto {
  final int id;
  final String name;
  final String city;
  final double fromPrice;
  final double rating;
  final String? thumbnailUrl;
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
