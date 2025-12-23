class AdminRoomTypeImageDto {
  final int id;
  final int roomTypeId;
  final String url;
  final int sortOrder;

  const AdminRoomTypeImageDto({
    required this.id,
    required this.roomTypeId,
    required this.url,
    required this.sortOrder,
  });

  factory AdminRoomTypeImageDto.fromJson(Map<String, dynamic> json) {
    int _asInt(dynamic v) {
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    return AdminRoomTypeImageDto(
      id: _asInt(json['id']),
      roomTypeId: _asInt(json['roomTypeId']),
      url: (json['url'] ?? '').toString(),
      sortOrder: _asInt(json['sortOrder']),
    );
  }
}

class AdminRoomTypeImageUpsertRequest {
  final int roomTypeId;
  final String url;
  final int sortOrder;

  const AdminRoomTypeImageUpsertRequest({
    required this.roomTypeId,
    required this.url,
    required this.sortOrder,
  });

  Map<String, dynamic> toJson() => {
        'roomTypeId': roomTypeId,
        'url': url,
        'sortOrder': sortOrder,
      };
}

class AdminRoomTypeImageReorderItem {
  final int id;
  final int sortOrder;

  const AdminRoomTypeImageReorderItem({
    required this.id,
    required this.sortOrder,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sortOrder': sortOrder,
      };
}
