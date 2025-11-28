class HotelSearchItemDto {
  final int id;
  final String name;
  final String city;
  final double fromPrice;
  final double rating;
  final String? thumbnailUrl;
  final bool hasAvailability;

  HotelSearchItemDto({
    required this.id,
    required this.name,
    required this.city,
    required this.fromPrice,
    required this.rating,
    required this.hasAvailability,
    this.thumbnailUrl,
  });

  factory HotelSearchItemDto.fromJson(Map<String, dynamic> json) {
    return HotelSearchItemDto(
      id: json['id'] as int,
      name: json['name'] as String,
      city: json['city'] as String? ?? '',
      fromPrice: (json['fromPrice'] as num?)?.toDouble() ?? 0.0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      hasAvailability: json['hasAvailability'] as bool? ?? true,
    );
  }
}
