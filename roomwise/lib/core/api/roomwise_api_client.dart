import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:roomwise/core/models/addon_dto.dart';
import 'package:roomwise/core/models/facility_dto.dart';
import 'package:roomwise/core/models/guest_booking_list_item_dto.dart';
import 'package:roomwise/core/models/payment_dto.dart';
import 'package:roomwise/core/models/reservation_dto.dart';
import 'package:roomwise/core/models/review_dto.dart';
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
    final response = await _dio.get(
      '/Cities',
      queryParameters: {'RetrieveAll': true, 'IncludeTotalCount': false},
    );
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

  // ---- HOTEL SEARCH ----
  Future<List<HotelSearchItemDto>> getAllHotels({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _dio.get(
      '/Hotels',
      queryParameters: {'Page': page, 'PageSize': pageSize},
    );

    final data = _extractList(response.data);
    return data
        .map(
          (json) => HotelSearchItemDto.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  // ---- HOTEL SEARCH ----
  Future<List<HotelSearchItemDto>> searchHotelsAdvanced({
    required DateTime checkIn,
    required DateTime checkOut,
    required int guests,
    String? query,
    int? cityId,
    double? minPrice,
    double? maxPrice,
    List<int>? addonIds,
    List<int>? facilityIds,
    int page = 1,
    int pageSize = 20,
    String? sort,
  }) async {
    // backend requires these
    if (checkOut.isBefore(checkIn) || checkOut.isAtSameMomentAs(checkIn)) {
      throw ArgumentError('checkOut must be after checkIn');
    }
    if (guests < 1) {
      throw ArgumentError('guests must be >= 1');
    }

    final qp = <String, dynamic>{
      'CheckIn': checkIn.toIso8601String(),
      'CheckOut': checkOut.toIso8601String(),
      'Guests': guests,
      'Page': page,
      'PageSize': pageSize,
    };

    // text query -> C# property Q
    final trimmed = query?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      qp['Q'] = trimmed;
    }

    if (cityId != null) qp['CityId'] = cityId;
    if (minPrice != null) qp['MinPrice'] = minPrice;
    if (maxPrice != null) qp['MaxPrice'] = maxPrice;

    if (addonIds != null && addonIds.isNotEmpty) {
      qp['AddOnIds'] = addonIds;
    }
    if (facilityIds != null && facilityIds.isNotEmpty) {
      qp['FacilityIds'] = facilityIds;
    }

    if (sort != null && sort.isNotEmpty) {
      qp['Sort'] = sort; // "price" | "rating" | ...
    }

    final response = await _dio.get('/search/hotels', queryParameters: qp);

    final data = _extractList(response.data);
    return data
        .map(
          (json) => HotelSearchItemDto.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  // ---- ADDONS ----
  Future<List<AddonDto>> getAddOns() async {
    final response = await _dio.get(
      '/AddOns',
      queryParameters: {'RetrieveAll': true, 'IncludeTotalCount': false},
    );
    final data = _extractList(response.data);
    return data
        .map((json) => AddonDto.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // ---- FACILITIES ----
  Future<List<FacilityDto>> getFacilities() async {
    final response = await _dio.get(
      '/Facilities',
      queryParameters: {'RetrieveAll': true, 'IncludeTotalCount': false},
    );
    final data = _extractList(response.data);
    return data
        .map((json) => FacilityDto.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // ---- RESERVATIONS ----

  Future<ReservationDto> createReservation(
    CreateReservationRequestDto request,
  ) async {
    debugPrint('CREATE RESERVATION REQUEST JSON: ${request.toJson()}');

    final response = await _dio.post('/Reservations', data: request.toJson());

    return ReservationDto.fromJson(response.data as Map<String, dynamic>);
  }

  // ---- PAYMENTS ----
  Future<PaymentIntentDto> createPaymentIntent({
    required int reservationId,
    required String paymentMethod,
  }) async {
    final body = {
      'reservationId': reservationId,
      'paymentMethod': paymentMethod,
    };

    debugPrint('CREATE PAYMENT INTENT REQUEST: $body');

    final response = await _dio.post('/Payments/intent', data: body);

    debugPrint('CREATE PAYMENT INTENT RESPONSE: ${response.data}');

    return PaymentIntentDto.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<ReservationDto>> getMyReservations({String? category}) async {
    final response = await _dio.get(
      '/Reservations/my',
      queryParameters: category == null ? null : {'category': category},
    );

    final data = response.data as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? const [];

    return items
        .map((e) => ReservationDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createReview(ReviewCreateRequestDto request) async {
    await _dio.post('/Reviews', data: request.toJson());
  }

  //TEST
  // Future<void> createReview({
  //   required int hotelId,
  //   required int reservationId,
  //   required int rating,
  //   String? comment,
  // }) async {
  //   await _dio.post('/reviews', data: {
  //     'hotelId': hotelId,
  //     'reservationId': reservationId,
  //     'rating': rating,
  //     if (comment != null && comment.isNotEmpty) 'comment': comment,
  //   });
  // }

  Future<List<GuestBookingListItemDto>> getMyBookings({
    required String status, // "Current" | "Past" | "Cancelled"
  }) async {
    final response = await _dio.get(
      '/reservations/my',
      queryParameters: {'status': status},
    );

    final data = _extractList(response.data);

    if (data.isEmpty &&
        !(response.data is Map &&
            (response.data as Map).containsKey('items'))) {
      debugPrint(
        'getMyBookings($status) empty or unexpected payload: '
        '${response.data.runtimeType} ${response.data}',
      );
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map((x) => GuestBookingListItemDto.fromJson(x))
        .toList();
  }

  Future<void> cancelReservation({
    int? reservationId,
    String? reservationPublicId,
  }) async {
    final target = reservationPublicId ?? reservationId?.toString();
    if (target == null || target.isEmpty) {
      throw ArgumentError('reservationId or reservationPublicId is required');
    }

    try {
      await _dio.post('/reservations/$target/cancel');
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 404 && reservationPublicId != null && reservationId != null) {
        await _dio.post('/reservations/${reservationId.toString()}/cancel');
        return;
      }
      rethrow;
    }
  }

  List<dynamic> _extractList(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List<dynamic>) return raw;

    if (raw is Map<String, dynamic>) {
      for (final key in const ['items', 'data', 'results', 'value', 'values']) {
        final value = raw[key];
        if (value is List<dynamic>) return value;
        if (value is Map<String, dynamic>) {
          final nested = _extractList(value);
          if (nested.isNotEmpty) return nested;
        }
      }

      for (final value in raw.values) {
        if (value is List<dynamic>) return value;
        if (value is Map<String, dynamic>) {
          final nested = _extractList(value);
          if (nested.isNotEmpty) return nested;
        }
      }
    }

    debugPrint('Unexpected response shape for list payload: $raw');
    return const [];
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
