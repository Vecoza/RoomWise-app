class HotelImageDto {
  final int id;
  final int hotelId;
  final String url;
  final int sortOrder;

  HotelImageDto({
    required this.id,
    required this.hotelId,
    required this.url,
    required this.sortOrder,
  });

  factory HotelImageDto.fromJson(Map<String, dynamic> json) {
    return HotelImageDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      hotelId: (json['hotelId'] as num?)?.toInt() ?? 0,
      url: json['url'] as String? ??
          json['imageUrl'] as String? ??
          json['thumbnailUrl'] as String? ??
          '',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }
}
