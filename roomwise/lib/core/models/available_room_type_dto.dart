class AvailableRoomTypeDto {
  final int id;
  final String name;
  final int capacity;
  final double priceFromPerNight;
  final int roomsLeft;
  final String? description;
  final String? bedConfiguration;
  final DateTime? validFrom;
  final DateTime? validTo;
  final double? sizeM2;

  // TEST
  final String? thumbnailUrl;
  final List<String> imageUrls;
  final String? bedType;
  final bool? isSmokingAllowed;

  AvailableRoomTypeDto({
    required this.id,
    required this.name,
    required this.capacity,
    required this.priceFromPerNight,
    this.roomsLeft = 0,
    this.description,
    this.bedConfiguration,
    this.validFrom,
    this.validTo,
    this.sizeM2,
    this.thumbnailUrl,
    this.imageUrls = const [],
    this.bedType,
    this.isSmokingAllowed,
  });

  factory AvailableRoomTypeDto.fromJson(Map<String, dynamic> json) {
    int _readInt(List<String> keys, {int fallback = 0}) {
      for (final k in keys) {
        final v = json[k];
        if (v == null) continue;
        if (v is int) return v;
        if (v is num) return v.toInt();
        if (v is String) {
          final parsed = int.tryParse(v);
          if (parsed != null) return parsed;
        }
      }
      return fallback;
    }

    double _readDouble(List<String> keys, {double fallback = 0.0}) {
      for (final k in keys) {
        final v = json[k];
        if (v == null) continue;
        if (v is num) return v.toDouble();
        if (v is String) {
          final parsed = double.tryParse(v);
          if (parsed != null) return parsed;
        }
      }
      return fallback;
    }

    final id = _readInt(['id', 'roomTypeId']);
    final price = _readDouble([
      'priceFromPerNight',
      'nightlyPrice',
      'fromPrice',
      'basePrice',
    ]);
    final size = _readDouble([
      'sizeM2',
      'roomSizeM2',
      'roomSize',
      'size',
    ], fallback: 0.0);

    return AvailableRoomTypeDto(
      id: id,
      name: (json['name'] as String?) ?? '',
      capacity: _readInt(['capacity'], fallback: 1),
      priceFromPerNight: price,
      roomsLeft: _readInt(['roomsLeft'], fallback: 0),
      description: json['description'] as String?,
      bedConfiguration: json['bedConfiguration'] as String?,
      sizeM2: size > 0 ? size : null,
      validFrom: json['validFrom'] != null
          ? DateTime.tryParse(json['validFrom'] as String)
          : null,
      validTo: json['validTo'] != null
          ? DateTime.tryParse(json['validTo'] as String)
          : null,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      imageUrls: (json['imageUrls'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      bedType: json['bedType'] as String?,
      isSmokingAllowed: json['isSmokingAllowed'] as bool?,
    );
  }
}
