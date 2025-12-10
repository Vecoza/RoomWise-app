import 'package:roomwise/core/models/available_room_type_dto.dart';
import 'package:roomwise/core/models/hotel_image_dto.dart';

import 'addon_dto.dart';
import 'facility_dto.dart';
import 'tag_dto.dart';

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
  final List<TagDto> tags;
  final List<HotelImageDto> images;

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
    this.tags = const [],
    this.images = const [],
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
        (json['addOns'] ?? json['addons'] ?? []) as List<dynamic>;

    final tagsJson =
        (json['tags'] as List?) ?? (hotelJson['tags'] as List?) ?? const [];

    // photos/gallery/images – pick first as hero, keep rest as gallery
    final imagesRaw =
        (json['photos'] as List?) ??
        (json['galleryUrls'] as List?) ??
        (json['images'] as List?) ??
        (hotelJson['images'] as List?) ??
        const [];

    final photos = imagesRaw
        .map((e) => e is String ? e : (e['url'] as String? ?? ''))
        .where((url) => url.isNotEmpty)
        .toList();

    final imageDtos =
        ((json['images'] as List?) ??
                (hotelJson['images'] as List?) ??
                const [])
            .whereType<Map<String, dynamic>>()
            .map(HotelImageDto.fromJson)
            .toList();

    // fallback: map string gallery to dto list if backend doesn't send objects
    final imagesFromPhotos = photos
        .asMap()
        .entries
        .map(
          (e) => HotelImageDto(
            id: e.key,
            hotelId: (hotelJson['id'] as int?) ?? 0,
            url: e.value,
            sortOrder: e.key,
          ),
        )
        .toList();

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
      currency:
          hotelJson['currency'] as String? ??
          json['currency'] as String? ??
          'EUR',
      address:
          hotelJson['addressLine'] as String? ??
          hotelJson['address'] as String?,
      description: hotelJson['description'] as String?,
      rating:
          (hotelJson['rating'] as num? ??
                  hotelJson['averageRating'] as num? ??
                  0)
              .toDouble(),
      heroImageUrl:
          (photos.isNotEmpty
              ? photos.first
              : hotelJson['heroImageUrl'] as String?) ??
          hotelJson['mainImageUrl'] as String? ??
          hotelJson['thumbnailUrl'] as String?,
      galleryUrls: photos,
      facilities: facilitiesJson.isNotEmpty
          ? facilitiesJson
                .map((e) => FacilityDto.fromJson(e as Map<String, dynamic>))
                .toList()
          : // backend returns "amenities": ["Free Wi-Fi", ...]
            (json['amenities'] as List<dynamic>? ?? const [])
                .map((e) => FacilityDto(id: 0, code: '', name: e.toString()))
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
      tags: tagsJson
          .map((e) => TagDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      images: imageDtos.isNotEmpty ? imageDtos : imagesFromPhotos,
    );
  }
}
