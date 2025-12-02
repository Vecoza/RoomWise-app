class ReviewCreateRequestDto {
  final int hotelId;
  final int rating; // 1-5
  final String? title;
  final String? body;
  final String? userId; // optional; backend can infer from token

  ReviewCreateRequestDto({
    required this.hotelId,
    required this.rating,
    this.title,
    this.body,
    this.userId,
  });

  Map<String, dynamic> toJson() => {
    'hotelId': hotelId,
    'rating': rating,
    'title': title,
    'body': body,
    'userId': userId,
  };
}
