import 'package:roomwise/core/models/available_room_type_dto.dart';

import 'addon_dto.dart';
import 'facility_dto.dart';

class HotelDetailsDto {
  final int id;
  final String name;
  final String city;
  final String? address;
  final double rating;
  final String? description;
  final String? heroImageUrl;
  final List<String> galleryUrls;
  final String currency;

  final List<FacilityDto> facilities;
  final List<AddonDto> addOns;
  final List<AvailableRoomTypeDto> availableRoomTypes;

  HotelDetailsDto({
    required this.id,
    required this.name,
    required this.city,
    required this.rating,
    this.currency = 'EUR',
    this.address,
    this.description,
    this.heroImageUrl,
    this.galleryUrls = const [],
    this.facilities = const [],
    this.addOns = const [],
    this.availableRoomTypes = const [],
  });

  factory HotelDetailsDto.fromJson(Map<String, dynamic> json) {
    final hotelJson = json['hotel'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['hotel'] as Map<String, dynamic>)
        : json;

    final facilitiesJson =
        (json['facilities'] as List?) ??
        (hotelJson['facilities'] as List?) ??
        const [];

    final addOnsJson =
        (json['addOns'] as List?) ??
        (hotelJson['addOns'] as List?) ??
        (json['addons'] as List?) ??
        const [];

    final imagesRaw =
        (json['galleryUrls'] as List?) ??
        (json['photos'] as List?) ??
        (json['images'] as List?) ??
        (hotelJson['images'] as List?) ??
        const [];

    return HotelDetailsDto(
      id: (hotelJson['id'] as int?) ?? (hotelJson['hotelId'] as int?) ?? 0,
      name:
          hotelJson['name'] as String? ??
          hotelJson['hotelName'] as String? ??
          '',
      city:
          hotelJson['city'] as String? ??
          hotelJson['cityName'] as String? ??
          '',
      currency: hotelJson['currency'] as String? ??
          json['currency'] as String? ??
          'EUR',
      address:
          hotelJson['address'] as String? ??
          hotelJson['addressLine'] as String?,
      description: hotelJson['description'] as String?,
      rating:
          (hotelJson['rating'] as num? ??
                  hotelJson['averageRating'] as num? ??
                  0)
              .toDouble(),
      heroImageUrl:
          hotelJson['heroImageUrl'] as String? ??
          hotelJson['mainImageUrl'] as String? ??
          hotelJson['thumbnailUrl'] as String?,
      galleryUrls: imagesRaw
          .map((e) => e is String ? e : (e['url'] as String? ?? ''))
          .where((url) => url.isNotEmpty)
          .toList(),
      facilities: facilitiesJson
          .map((e) => FacilityDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      addOns: addOnsJson
          .map((e) => AddonDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      availableRoomTypes:
          ((json['availableRoomTypes'] as List?) ??
                  (json['roomTypes'] as List?) ??
                  (json['rooms'] as List?) ??
                  const [])
              .map(
                (e) => AvailableRoomTypeDto.fromJson(e as Map<String, dynamic>),
              )
              .toList(),
    );
  }
}
