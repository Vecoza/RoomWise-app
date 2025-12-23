class ReviewCreateRequestDto {
  final int hotelId;
  final int reservationId;
  final int rating; // 1-5
  final String? title;
  final String? body;

  ReviewCreateRequestDto({
    required this.hotelId,
    required this.reservationId,
    required this.rating,
    this.title,
    this.body,
  });

  Map<String, dynamic> toJson() => {
        'hotelId': hotelId,
        'reservationId': reservationId,
        'rating': rating,
        if (title != null) 'title': title,
        if (body != null) 'body': body,
        if (body != null) 'comment': body,
      };
}

class ReviewDto {
  final int id;
  final int hotelId;
  final int? reservationId;
  final String userId;
  final double rating;
  final String? title;
  final String? body;
  final DateTime? createdAt;

  ReviewDto({
    required this.id,
    required this.hotelId,
    required this.reservationId,
    required this.userId,
    required this.rating,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  factory ReviewDto.fromJson(Map<String, dynamic> json) {
    double _asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    int _asInt(dynamic v) {
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    DateTime? _asDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());

    return ReviewDto(
      id: _asInt(json['id']),
      hotelId: _asInt(json['hotelId']),
      reservationId:
          json['reservationId'] == null ? null : _asInt(json['reservationId']),
      userId: (json['userId'] ?? '').toString(),
      rating: _asDouble(json['rating']),
      title: json['title']?.toString(),
      body: json['body']?.toString() ?? json['comment']?.toString(),
      createdAt: _asDate(json['createdAt']),
    );
  }
}
