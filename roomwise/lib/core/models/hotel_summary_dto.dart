class HotelSummaryDto {
  final int id;
  final String name;
  final String cityName;
  final String countryName;
  final double minPricePerNight;
  final double averageRating;
  final String? thumbnailUrl;
  final bool hasAvailability;

  HotelSummaryDto({
    required this.id,
    required this.name,
    required this.cityName,
    required this.countryName,
    required this.minPricePerNight,
    required this.averageRating,
    required this.hasAvailability,
    this.thumbnailUrl,
  });

  factory HotelSummaryDto.fromJson(Map<String, dynamic> json) {
    return HotelSummaryDto(
      id: json['id'] as int,
      name: json['name'] as String,

      cityName: json['city'] as String? ?? '',
      countryName: json['countryName'] as String? ?? 'Bosnia & Herzegovina',
      minPricePerNight: (json['fromPrice'] as num?)?.toDouble() ?? 0.0,
      averageRating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      hasAvailability: json['hasAvailability'] as bool? ?? true,
    );
  }
}
