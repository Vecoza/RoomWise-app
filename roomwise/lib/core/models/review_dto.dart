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
    // Some backends expect "comment" instead of "body"
    if (body != null) 'comment': body,
  };
}
