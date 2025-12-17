import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:roomwise/core/auth/auth_state.dart';
import 'package:roomwise/core/models/addon_dto.dart';
import 'package:roomwise/core/models/facility_dto.dart';
import 'package:roomwise/core/models/guest_booking_list_item_dto.dart';
import 'package:roomwise/core/models/payment_dto.dart';
import 'package:roomwise/core/models/reservation_dto.dart';
import 'package:roomwise/core/models/review_dto.dart';
import 'package:roomwise/core/models/me_profile_dto.dart';
import 'package:roomwise/core/models/loyalty_summary_dto.dart';
import 'package:roomwise/core/models/wishlist_item_dto.dart';
import 'package:roomwise/core/models/notification_dto.dart';
import 'package:roomwise/core/models/paged_result.dart';
import 'package:roomwise/core/models/loyalty_dtos.dart';
import 'package:roomwise/core/models/review_response_dto.dart';
import 'package:roomwise/core/models/tag_dto.dart';
import 'api_config.dart';
import '../models/city_dto.dart';
import '../models/hotel_search_item_dto.dart';
import '../models/hotel_details_dto.dart';
import '../models/auth_dto.dart';

class RoomWiseApiClient {
  static const bool _logApi = false;

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
          if (_logApi) {
            debugPrint(
              '[API] → ${options.method} ${options.uri} '
              'data=${_safeDataPreview(options.data)}',
            );
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (_logApi) {
            debugPrint(
              '[API] ← ${response.requestOptions.method} '
              '${response.requestOptions.uri} '
              'status=${response.statusCode}',
            );
          }
          return handler.next(response);
        },
        onError: (error, handler) async {
          final statusCode = error.response?.statusCode;
          final path = error.requestOptions.path.toLowerCase();
          final isAuthEndpoint = path.contains('/auth/login') ||
              path.contains('/auth/register') ||
              path.contains('/auth/refresh');

          if (statusCode == 401 &&
              !isAuthEndpoint &&
              _authState != null &&
              !_isRefreshing) {
            _isRefreshing = true;
            _refreshCompleter = Completer<void>();
            final auth = _authState!;
            final didRefresh = await auth.tryRefreshToken();
            _refreshCompleter?.complete();
            _refreshCompleter = null;
            _isRefreshing = false;

            if (didRefresh && auth.token != null) {
              error.requestOptions.headers['Authorization'] =
                  'Bearer ${auth.token}';
              try {
                final retryResponse = await _dio.fetch(error.requestOptions);
                return handler.resolve(retryResponse);
              } catch (e) {
                return handler.reject(e as DioException);
              }
            }
          } else if (_isRefreshing && _refreshCompleter != null) {
            await _refreshCompleter!.future;
            if (_authState?.token != null) {
              error.requestOptions.headers['Authorization'] =
                  'Bearer ${_authState!.token}';
              try {
                final retryResponse = await _dio.fetch(error.requestOptions);
                return handler.resolve(retryResponse);
              } catch (e) {
                return handler.reject(e as DioException);
              }
            }
          }

          if (_logApi) {
            debugPrint(
              '[API] ✖ ${error.requestOptions.method} '
              '${error.requestOptions.uri} '
              'status=${error.response?.statusCode} '
              'message=${error.message}',
            );
          }
          return handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  String? _authToken;
  AuthState? _authState;
  bool _isRefreshing = false;
  Completer<void>? _refreshCompleter;

  void setAuthToken(String? token) {
    _authToken = _stripBearer(token);
  }

  void attachAuthState(AuthState auth) {
    _authState = auth;
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
    // debugPrint('Hot deals raw response: ${response.data}');
    final data = _extractList(response.data);
    return data
        .map(
          (json) => HotelSearchItemDto.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  // ---- RECOMMENDATIONS ----
  Future<List<HotelSearchItemDto>> getRecommendations({int top = 5}) async {
    try {
      final response = await _dio.get(
        '/Hotels/recommendations',
        queryParameters: {'top': top},
      );
      final data = _extractList(response.data);
      return data
          .map(
            (json) => HotelSearchItemDto.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      // Treat 404 as "no recommendations available" instead of crashing UI.
      if (e.response?.statusCode == 404) return [];
      rethrow;
    }
  }

  // ---- TAGS CATEGORIES ----
  Future<List<TagDto>> getTags() async {
    final response = await _dio.get(
      '/Tags',
      queryParameters: {'RetrieveAll': true, 'IncludeTotalCount': false},
    );
    final data = _extractList(response.data);
    return data
        .map((json) => TagDto.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<HotelSearchItemDto>> getHotelsByTag(
    int tagId, {
    String? tagName,
  }) async {
    final response = await _dio.get(
      '/Hotels/search',
      queryParameters: {
        'TagId': tagId,
        if (tagName != null && tagName.isNotEmpty) 'TagName': tagName,
        'RetrieveAll': true,
        'IncludeTotalCount': false,
      },
    );

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
      '/Hotels/search',
      queryParameters: {
        'CityId': cityId,
        'Page': _toZeroBasedPage(page),
        'PageSize': pageSize,
        'RetrieveAll': true,
        'IncludeTotalCount': false,
      },
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

  Future<AuthResponseDto> refreshToken(String refreshToken) async {
    final response = await _dio.post(
      '/Auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    return AuthResponseDto.fromJson(response.data as Map<String, dynamic>);
  }

  // ---- PROFILE / ME ----

  Future<MeProfileDto> getMyProfile() async {
    // Primary path (lowercase)
    try {
      final response = await _dio.get('/me/profile');
      return MeProfileDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      debugPrint(
        'getMyProfile /me/profile failed: '
        'status=${e.response?.statusCode}, data=${e.response?.data}',
      );
      // Some backends are case-sensitive; retry with original casing before propagating.
      if (e.response?.statusCode == 404 || e.response?.statusCode == 500) {
        try {
          final fallback = await _dio.get('/Me/profile');
          return MeProfileDto.fromJson(fallback.data as Map<String, dynamic>);
        } on DioException catch (e2) {
          debugPrint(
            'getMyProfile /Me/profile failed: '
            'status=${e2.response?.statusCode}, data=${e2.response?.data}',
          );
          rethrow;
        }
      }
      rethrow;
    }
  }

  Future<void> updateMyProfile(UpdateProfileRequestDto request) async {
    await _dio.put('/Me/profile', data: request.toJson());
  }

  Future<void> changeMyPassword(ChangePasswordRequestDto request) async {
    await _dio.post('/Me/profile/change-password', data: request.toJson());
  }

  Future<LoyaltySummaryDto> getMyLoyaltyBalance() async {
    final response = await _dio.get('/Loyalty/balance');
    return LoyaltySummaryDto.fromJson(response.data as Map<String, dynamic>);
  }

  Future<LoyaltyBalanceDto> getLoyaltyBalance() async {
    try {
      final response = await _dio.get('/Loyalty/balance');
      return LoyaltyBalanceDto.fromJson(response.data);
    } on DioException catch (e) {
      debugPrint(
        'getLoyaltyBalance failed: status=${e.response?.statusCode}, data=${e.response?.data}',
      );
      rethrow;
    }
  }

  Future<LoyaltyHistoryPageDto> getLoyaltyHistoryPage({
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      final response = await _dio.get(
        '/api/loyalty/history',
        queryParameters: {'page': _toZeroBasedPage(page), 'pageSize': pageSize},
      );
      return LoyaltyHistoryPageDto.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 || e.response?.statusCode == 405) {
        final response = await _dio.get(
          '/Loyalty/history',
          queryParameters: {
            'Page': _toZeroBasedPage(page),
            'PageSize': pageSize,
          },
        );
        return LoyaltyHistoryPageDto.fromJson(response.data);
      }
      rethrow;
    }
  }

  Future<String> uploadAvatar(File file) async {
    final fileName = file.path.split(Platform.pathSeparator).last;
    Future<FormData> buildFormData() async {
      return FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: fileName),
      });
    }

    try {
      debugPrint('Uploading avatar → /me/profile/avatar ($fileName)');
      final response = await _dio.post(
        '/me/profile/avatar',
        data: await buildFormData(),
      );
      debugPrint(
        'Avatar upload success /me/profile/avatar: ${response.statusCode}',
      );
      return _extractAvatarUrl(response.data);
    } on DioException catch (e) {
      debugPrint(
        'Avatar upload /me/profile/avatar failed: '
        'status=${e.response?.statusCode}, data=${e.response?.data}',
      );
      rethrow;
    }
  }

  Future<PagedResult<ReviewResponseDto>> getHotelReviews({
    required int hotelId,
    int page = 1,
    int pageSize = 10,
  }) async {
    final qp = {'page': _toZeroBasedPage(page), 'pageSize': pageSize};
    final paths = ['/hotels/$hotelId/reviews'];

    DioException? lastError;
    for (final path in paths) {
      try {
        final response = await _dio.get(path, queryParameters: qp);
        final data = response.data as Map<String, dynamic>;
        return PagedResult<ReviewResponseDto>.fromJson(
          data,
          (json) => ReviewResponseDto.fromJson(json),
        );
      } on DioException catch (e) {
        lastError = e;
        continue;
      }
    }
    if (lastError?.response?.statusCode == 404) {
      return PagedResult<ReviewResponseDto>(items: const [], totalCount: 0);
    }
    throw lastError ??
        DioException(
          requestOptions: RequestOptions(
            path: '/reviews/hotel/$hotelId',
            queryParameters: qp,
          ),
          error: 'Failed to load reviews',
        );
  }

  // ---- NOTIFICATIONS ----

  Future<PagedResult<NotificationDto>> getMyNotifications({
    int page = 1,
    int pageSize = 20,
  }) async {
    final qp = {'Page': _toZeroBasedPage(page), 'PageSize': pageSize};

    try {
      final response = await _dio.get('/Me/notifications', queryParameters: qp);
      return _parseNotifications(response.data);
    } on DioException catch (e) {
      // Fallbacks for different casing / routing
      if (e.response?.statusCode == 404 || e.response?.statusCode == 405) {
        final response = await _dio.get(
          '/api/me/notifications',
          queryParameters: {
            'page': _toZeroBasedPage(page),
            'pageSize': pageSize,
          },
        );
        return _parseNotifications(response.data);
      }
      rethrow;
    }
  }

  Future<void> markNotificationAsRead(int id) async {
    try {
      await _dio.post('/Me/notifications/$id/read');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 || e.response?.statusCode == 405) {
        await _dio.post('/api/me/notifications/$id/read');
        return;
      }
      rethrow;
    }
  }

  // ---- WISHLIST ----

  Future<List<WishlistItemDto>> getWishlist() async {
    final response = await _dio.get('/Wishlist');
    final data = _extractList(response.data);
    final items = <WishlistItemDto>[];
    for (final raw in data) {
      final hotel = _parseWishlistHotel(raw);
      if (hotel == null) continue;
      final map = raw is Map<String, dynamic>
          ? raw
          : (raw is Map ? Map<String, dynamic>.from(raw) : null);
      if (map == null) continue;
      final item = _parseWishlistItem(map, hotel);
      if (item != null) items.add(item);
    }
    return items;
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
      queryParameters: {'Page': _toZeroBasedPage(page), 'PageSize': pageSize},
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
      'Page': _toZeroBasedPage(page),
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

    final response = await _dio.get(
      '/Hotels/search',
      queryParameters: qp,
    ); //here

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

  Future<CreateReservationWithIntentResponse> createReservationWithIntent(
    CreateReservationRequestDto request,
  ) async {
    debugPrint(
      'CREATE RESERVATION WITH INTENT REQUEST JSON: ${request.toJson()}',
    );

    final response = await _dio.post(
      '/reservations/with-payment-intent',
      data: request.toJson(),
    );

    return CreateReservationWithIntentResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  // ---- PAYMENTS ----
  Future<PaymentIntentDto> createPaymentIntent({
    required int reservationId,
    required String paymentMethod,
    int? loyaltyPointsToRedeem,
  }) async {
    final body = {
      'reservationId': reservationId,
      'paymentMethod': paymentMethod,
      if (loyaltyPointsToRedeem != null) 'loyaltyPointsToRedeem': loyaltyPointsToRedeem,
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

  // Future<void> cancelReservation({
  //   int? reservationId,
  //   String? reservationPublicId,
  // }) async {
  //   final target = reservationPublicId ?? reservationId?.toString();
  //   if (target == null || target.isEmpty) {
  //     throw ArgumentError('reservationId or reservationPublicId is required');
  //   }

  //   try {
  //     await _dio.post('/reservations/$target/cancel');
  //   } on DioException catch (e) {
  //     final code = e.response?.statusCode;
  //     if (code == 404 && reservationPublicId != null && reservationId != null) {
  //       await _dio.post('/reservations/${reservationId.toString()}/cancel');
  //       return;
  //     }
  //     rethrow;
  //   }
  // }
  Future<void> cancelReservation(int reservationId) async {
    try {
      await _dio.post('/reservations/$reservationId/cancel');
    } on DioException catch (e) {
      debugPrint(
        'Cancel reservation error: '
        'status=${e.response?.statusCode}, data=${e.response?.data}',
      );
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

  PagedResult<NotificationDto> _parseNotifications(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return PagedResult<NotificationDto>.fromJson(
        raw,
        (json) => NotificationDto.fromJson(json),
      );
    }

    final list = _extractList(
      raw,
    ).whereType<Map<String, dynamic>>().map(NotificationDto.fromJson).toList();

    return PagedResult<NotificationDto>(items: list, totalCount: list.length);
  }

  String _extractAvatarUrl(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final url =
          raw['avatarBase64'] ??
          raw['avatarUrl'] ??
          raw['avatarURL'] ??
          raw['url'] ??
          raw['AvatarUrl'];
      if (url is String && url.isNotEmpty) return url;
    }
    if (raw is String && raw.isNotEmpty) return raw;
    throw DioException(
      requestOptions: RequestOptions(path: '/api/me/avatar'),
      error: 'Avatar data not returned from server',
    );
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

  int _toZeroBasedPage(int page) {
    if (page <= 0) return 0;
    return page - 1;
  }

  WishlistItemDto? _parseWishlistItem(
    Map<String, dynamic> raw,
    HotelSearchItemDto hotel,
  ) {
    final id = _tryParseInt(raw['id']) ?? 0;
    final hotelId = _tryParseInt(raw['hotelId']) ?? hotel.id;
    final createdAt =
        DateTime.tryParse(raw['createdAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);

    return WishlistItemDto(
      id: id,
      userId: raw['userId']?.toString() ?? '',
      hotelId: hotelId,
      createdAt: createdAt,
      hotel: hotel,
    );
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

  int? _tryParseInt(dynamic raw) {
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  String _safeDataPreview(Object? data) {
    try {
      final str = data.toString();
      if (str.length > 200) return '${str.substring(0, 200)}...';
      return str;
    } catch (_) {
      return '<unprintable>';
    }
  }
}
