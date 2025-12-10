class ReviewResponseDto {
  final int id;
  final int hotelId;
  final String? userId;
  final int rating;
  final String? title;
  final String? body;
  final DateTime createdAt;

  ReviewResponseDto({
    required this.id,
    required this.hotelId,
    required this.userId,
    required this.rating,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  factory ReviewResponseDto.fromJson(Map<String, dynamic> json) {
    return ReviewResponseDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      hotelId: (json['hotelId'] as num?)?.toInt() ?? 0,
      userId: json['userId'] as String?,
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      title: json['title'] as String?,
      body: json['body'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
