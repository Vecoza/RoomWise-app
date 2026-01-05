import 'package:roomwise/core/models/reservation_addOn_item_dto.dart';
import 'package:roomwise/core/models/payment_dto.dart';

class ReservationPreviewRequestDto {
  final int hotelId;
  final int roomTypeId;
  final DateTime checkIn;
  final DateTime checkOut;
  final int guests;
  final List<int> addonIds;
  final String paymentMethod;

  ReservationPreviewRequestDto({
    required this.hotelId,
    required this.roomTypeId,
    required this.checkIn,
    required this.checkOut,
    required this.guests,
    this.addonIds = const [],
    this.paymentMethod = 'Card',
  });

  Map<String, dynamic> toJson() => {
    'hotelId': hotelId,
    'roomTypeId': roomTypeId,
    'checkIn': checkIn.toIso8601String(),
    'checkOut': checkOut.toIso8601String(),
    'guests': guests,
    'addonIds': addonIds,
    'paymentMethod': paymentMethod,
  };
}

class CreateReservationWithIntentResponse {
  final ReservationDto reservation;
  final PaymentIntentDto payment;
  final String clientSecret;

  CreateReservationWithIntentResponse({
    required this.reservation,
    required this.payment,
    required this.clientSecret,
  });

  factory CreateReservationWithIntentResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return CreateReservationWithIntentResponse(
      reservation: ReservationDto.fromJson(
        json['reservation'] as Map<String, dynamic>,
      ),
      payment: PaymentIntentDto.fromJson(
        json['payment'] as Map<String, dynamic>,
      ),
      clientSecret: json['clientSecret'] as String? ?? '',
    );
  }
}

class ReservationPreviewDto {
  final int nights;
  final double roomTotal;
  final double addOnsTotal;
  final double taxes;
  final double grandTotal;
  final String currency;

  ReservationPreviewDto({
    required this.nights,
    required this.roomTotal,
    required this.addOnsTotal,
    required this.taxes,
    required this.grandTotal,
    required this.currency,
  });

  factory ReservationPreviewDto.fromJson(Map<String, dynamic> json) {
    return ReservationPreviewDto(
      nights: json['nights'] as int? ?? 1,
      roomTotal: (json['roomTotal'] as num?)?.toDouble() ?? 0.0,
      addOnsTotal: (json['addOnsTotal'] as num?)?.toDouble() ?? 0.0,
      taxes: (json['taxes'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (json['grandTotal'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'EUR',
    );
  }
}

class CreateReservationRequestDto {
  final int hotelId;
  final int roomTypeId;
  final DateTime checkIn;
  final DateTime checkOut;
  final int guests;
  final List<ReservationAddOnItemDto> addOns;
  final String paymentMethod;
  final int? loyaltyPointsToRedeem;

  CreateReservationRequestDto({
    required this.hotelId,
    required this.roomTypeId,
    required this.checkIn,
    required this.checkOut,
    required this.guests,
    this.addOns = const [],
    required this.paymentMethod,
    this.loyaltyPointsToRedeem,
  });

  Map<String, dynamic> toJson() => {
    'hotelId': hotelId,
    'roomTypeId': roomTypeId,
    'checkIn': checkIn.toIso8601String(),
    'checkOut': checkOut.toIso8601String(),
    'guests': guests,
    'addOns': addOns.map((a) => a.toJson()).toList(),
    'paymentMethod': paymentMethod,
    if (loyaltyPointsToRedeem != null)
      'loyaltyPointsToRedeem': loyaltyPointsToRedeem,
  };
}

class ReservationDto {
  final int id;
  final String publicId;
  final int? hotelId;
  final DateTime checkIn;
  final DateTime checkOut;
  final int guests;
  final double total;
  final String currency;
  final String status;
  final String? confirmationNumber;

  final String? hotelName;
  final String? hotelCity;
  final String? mainImageUrl;
  final String? roomTypeName;

  ReservationDto({
    required this.id,
    required this.publicId,
    required this.hotelId,
    required this.checkIn,
    required this.checkOut,
    required this.guests,
    required this.total,
    required this.currency,
    required this.status,
    this.confirmationNumber,
    this.hotelName,
    this.hotelCity,
    this.mainImageUrl,
    this.roomTypeName,
  });

  factory ReservationDto.fromJson(Map<String, dynamic> json) {
    final hotel = json['hotel'] as Map<String, dynamic>?;

    String? hotelName;
    String? hotelCity;
    String? mainImageUrl;

    if (hotel != null) {
      hotelName = hotel['name'] as String?;

      final city = hotel['city'] as Map<String, dynamic>?;
      hotelCity = city?['name'] as String? ?? hotel['cityName'] as String?;

      final images = hotel['images'] as List<dynamic>?;
      if (images != null && images.isNotEmpty) {
        final first = images.first as Map<String, dynamic>;
        mainImageUrl = first['url'] as String?;
      }
    }

    return ReservationDto(
      id: json['id'] as int,
      publicId: json['publicId'] as String,
      hotelId: json['hotelId'] as int? ?? hotel?['id'] as int?,
      checkIn: DateTime.parse(json['checkIn'] as String),
      checkOut: DateTime.parse(json['checkOut'] as String),
      guests: json['guests'] as int? ?? 1,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'EUR',
      status: json['status'] as String? ?? '',
      confirmationNumber: json['confirmationNumber'] as String?,
      hotelName: hotelName,
      hotelCity: hotelCity,
      mainImageUrl: mainImageUrl,
      roomTypeName:
          json['roomTypeName'] as String? ??
          json['roomType'] as String? ??
          (json['roomTypeDto'] as Map<String, dynamic>?)?['name'] as String?,
    );
  }
}
