import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_config.dart';
import '../models/city_dto.dart';
import '../models/hotel_search_item_dto.dart';
import '../models/hotel_details_dto.dart'; // we’ll create this in Step 3
import '../models/auth_dto.dart';

class RoomWiseApiClient {
  RoomWiseApiClient({String? hostOverride})
    : _dio = Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl(overrideHost: hostOverride),
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_authToken != null && _authToken!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_authToken';
          }
          return handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  String? _authToken;

  void setAuthToken(String? token) {
    _authToken = _stripBearer(token);
  }

  // ---- CITIES ----
  Future<List<CityDto>> getCities() async {
    final response = await _dio.get('/Cities');
    final data = _extractList(response.data);
    return data
        .map((json) => CityDto.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // ---- HOT DEALS  ----
  Future<List<HotelSearchItemDto>> getHotDeals() async {
    final response = await _dio.get('/Hotels/hot-deals');
    final data = _extractList(response.data);
    return data
        .map(
          (json) => HotelSearchItemDto.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  // ---- HOTEL SEARCH  ----
  Future<List<HotelSearchItemDto>> searchHotelsByCity({
    required int cityId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _dio.get(
      '/Hotels',
      queryParameters: {'CityId': cityId, 'Page': page, 'PageSize': pageSize},
    );

    final data = _extractList(response.data);
    return data
        .map(
          (json) => HotelSearchItemDto.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  // ---- HOTEL DETAILS ----
  Future<HotelDetailsDto> getHotelDetails({
    required int hotelId,
    DateTime? checkIn,
    DateTime? checkOut,
    int? guests,
  }) async {
    final qp = <String, dynamic>{};
    if (checkIn != null) qp['CheckIn'] = checkIn.toIso8601String();
    if (checkOut != null) qp['CheckOut'] = checkOut.toIso8601String();
    if (guests != null) qp['Guests'] = guests;

    final response = await _dio.get(
      '/Hotels/$hotelId/details',
      queryParameters: qp.isEmpty ? null : qp,
    );

    return HotelDetailsDto.fromJson(response.data as Map<String, dynamic>);
  }

  // ---- AUTH ----
  Future<void> registerGuest(RegisterRequestDto request) async {
    await _dio.post('/Auth/register', data: request.toJson());
  }

  Future<AuthResponseDto> loginGuest(LoginRequestDto request) async {
    final response = await _dio.post('/Auth/login', data: request.toJson());
    return AuthResponseDto.fromJson(response.data as Map<String, dynamic>);
  }

  // ---- WISHLIST ----

  Future<List<HotelSearchItemDto>> getWishlist() async {
    final response = await _dio.get('/Wishlist');
    final data = _extractList(response.data);
    final hotels = <HotelSearchItemDto>[];
    for (final raw in data) {
      final parsed = _parseWishlistHotel(raw);
      if (parsed != null) hotels.add(parsed);
    }
    return hotels;
  }

  Future<void> addToWishlist(int hotelId) async {
    try {
      await _dio.post('/Wishlist/$hotelId');
    } on DioException catch (e) {
      if (_shouldRetryWishlist(e)) {
        await _dio.post('/Wishlist', data: {'hotelId': hotelId});
        return;
      }
      rethrow;
    }
  }

  Future<void> removeFromWishlist(int hotelId) async {
    try {
      await _dio.delete('/Wishlist/$hotelId');
    } on DioException catch (e) {
      if (_shouldRetryWishlist(e)) {
        await _dio.delete('/Wishlist', queryParameters: {'hotelId': hotelId});
        return;
      }
      rethrow;
    }
  }

  // ---- Helper for paged responses ----
  List<dynamic> _extractList(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List<dynamic>) return raw;
    if (raw is Map<String, dynamic>) {
      for (final key in const ['items', 'data', 'results']) {
        final value = raw[key];
        if (value is List<dynamic>) return value;
        if (value is Map<String, dynamic>) {
          for (final nestedKey in const ['items', 'data', 'results']) {
            final nestedValue = value[nestedKey];
            if (nestedValue is List<dynamic>) return nestedValue;
          }
        }
      }

      for (final value in raw.values) {
        if (value is List<dynamic>) return value;
      }
    }
    throw StateError('Unexpected response shape for list payload: $raw');
  }

  bool _shouldRetryWishlist(DioException e) {
    final code = e.response?.statusCode;
    return code == 404 || code == 405;
  }

  String? _stripBearer(String? token) {
    if (token == null) return null;
    final trimmed = token.trim();
    if (trimmed.toLowerCase().startsWith('bearer ')) {
      return trimmed.substring(7).trim();
    }
    return trimmed;
  }

  HotelSearchItemDto? _parseWishlistHotel(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;

    final hotelJson = raw['hotel'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(raw['hotel'] as Map<String, dynamic>)
        : Map<String, dynamic>.from(raw);

    hotelJson['id'] ??= raw['hotelId'];
    hotelJson['name'] ??= hotelJson['hotelName'] ?? raw['hotelName'];
    hotelJson['city'] ??= hotelJson['cityName'] ?? raw['cityName'];
    hotelJson['fromPrice'] ??=
        hotelJson['minPricePerNight'] ?? raw['minPricePerNight'];
    hotelJson['rating'] ??= hotelJson['averageRating'] ?? raw['averageRating'];
    hotelJson['thumbnailUrl'] ??= hotelJson['thumbnail'] ?? raw['thumbnail'];
    hotelJson['hasAvailability'] ??= true;

    if (hotelJson['id'] == null || hotelJson['name'] == null) {
      debugPrint('Wishlist item missing id/name, skipping: $raw');
      return null;
    }

    try {
      return HotelSearchItemDto.fromJson(hotelJson);
    } catch (e) {
      debugPrint('Failed to parse wishlist hotel: $e');
      return null;
    }
  }
}
