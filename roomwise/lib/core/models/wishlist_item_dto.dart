class WishlistItemDto {
  final int id;
  final int hotelId;
  final String? userId;
  final DateTime? createdAt;

  WishlistItemDto({
    required this.id,
    required this.hotelId,
    this.userId,
    this.createdAt,
  });

  factory WishlistItemDto.fromJson(Map<String, dynamic> json) {
    return WishlistItemDto(
      id: json['id'] as int,
      hotelId: json['hotelId'] as int,
      userId: json['userId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }
}
