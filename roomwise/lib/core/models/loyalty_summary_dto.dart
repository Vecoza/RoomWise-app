class LoyaltySummaryDto {
  final String userId;
  final int balance;

  LoyaltySummaryDto({required this.userId, required this.balance});

  factory LoyaltySummaryDto.fromJson(Map<String, dynamic> json) {
    return LoyaltySummaryDto(
      userId: json['userId'] as String? ?? '',
      balance: (json['balance'] as num?)?.toInt() ?? 0,
    );
  }
}
