class AdminHotelImageDto {
  final int id;
  final int hotelId;
  final String url;
  final int sortOrder;

  const AdminHotelImageDto({
    required this.id,
    required this.hotelId,
    required this.url,
    required this.sortOrder,
  });

  factory AdminHotelImageDto.fromJson(Map<String, dynamic> json) {
    int _asInt(dynamic v) {
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    return AdminHotelImageDto(
      id: _asInt(json['id']),
      hotelId: _asInt(json['hotelId']),
      url: (json['url'] ?? '').toString(),
      sortOrder: _asInt(json['sortOrder']),
    );
  }
}

class AdminHotelImageUpsertRequest {
  final String url;
  final int sortOrder;

  const AdminHotelImageUpsertRequest({
    required this.url,
    required this.sortOrder,
  });

  Map<String, dynamic> toJson() => {
        'url': url,
        'sortOrder': sortOrder,
      };
}
