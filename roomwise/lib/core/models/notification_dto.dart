class NotificationDto {
  final int id;
  final String userId;
  final int? reservationId;
  final String type;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  NotificationDto({
    required this.id,
    required this.userId,
    required this.reservationId,
    required this.type,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationDto.fromJson(Map<String, dynamic> json) {
    return NotificationDto(
      id: (json['id'] as num).toInt(),
      userId: json['userId'] as String? ?? '',
      reservationId: json['reservationId'] as int?,
      type: json['type'] as String? ?? '',
      message: json['message'] as String? ?? '',
      isRead: json['isRead'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
