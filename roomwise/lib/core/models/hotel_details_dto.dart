class AvailableRoomTypeDto {
  final int roomTypeId;
  final String name;
  final int capacity;
  final double nightlyPrice;
  final int roomsLeft;

  AvailableRoomTypeDto({
    required this.roomTypeId,
    required this.name,
    required this.capacity,
    required this.nightlyPrice,
    required this.roomsLeft,
  });

  factory AvailableRoomTypeDto.fromJson(Map<String, dynamic> json) {
    return AvailableRoomTypeDto(
      roomTypeId: json['roomTypeId'] as int,
      name: json['name'] as String,
      capacity: json['capacity'] as int,
      nightlyPrice: (json['nightlyPrice'] as num).toDouble(),
      roomsLeft: json['roomsLeft'] as int,
    );
  }
}

class HotelDetailsDto {
  final int id;
  final String name;
  final String addressLine;
  final String description;
  final double rating;
  final String city;
  final List<String> amenities;
  final List<String> photos;
  final List<AvailableRoomTypeDto> availableRoomTypes;

  HotelDetailsDto({
    required this.id,
    required this.name,
    required this.addressLine,
    required this.description,
    required this.rating,
    required this.city,
    required this.amenities,
    required this.photos,
    required this.availableRoomTypes,
  });

  factory HotelDetailsDto.fromJson(Map<String, dynamic> json) {
    final amenitiesRaw = json['amenities'] as List<dynamic>? ?? const [];
    final photosRaw = json['photos'] as List<dynamic>? ?? const [];
    final roomsRaw = json['availableRoomTypes'] as List<dynamic>? ?? const [];

    return HotelDetailsDto(
      id: json['id'] as int,
      name: json['name'] as String,
      addressLine: json['addressLine'] as String? ?? '',
      description: json['description'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      city: json['city'] as String? ?? '',
      amenities: amenitiesRaw.map((e) => e.toString()).toList(),
      photos: photosRaw.map((e) => e.toString()).toList(),
      availableRoomTypes: roomsRaw
          .map((e) => AvailableRoomTypeDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
