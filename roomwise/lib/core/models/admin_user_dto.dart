import 'package:roomwise/core/models/loyalty_dtos.dart';

class AdminUserSummaryDto {
  final String userId;
  final String email;
  final String firstName;
  final String lastName;
  final String? phone;
  final int loyaltyBalance;
  final DateTime createdAt;

  const AdminUserSummaryDto({
    required this.userId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.loyaltyBalance,
    required this.createdAt,
  });

  factory AdminUserSummaryDto.fromJson(Map<String, dynamic> json) {
    DateTime _asDate(dynamic v) =>
        DateTime.tryParse(v?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);

    return AdminUserSummaryDto(
      userId: (json['userId'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      firstName: (json['firstName'] ?? '').toString(),
      lastName: (json['lastName'] ?? '').toString(),
      phone: json['phone']?.toString(),
      loyaltyBalance: (json['loyaltyBalance'] as num?)?.toInt() ?? 0,
      createdAt: _asDate(json['createdAt']),
    );
  }
}

class AdminUserLoyaltyDto {
  final int balance;
  final List<LoyaltyHistoryItemDto> history;

  const AdminUserLoyaltyDto({
    required this.balance,
    required this.history,
  });

  factory AdminUserLoyaltyDto.fromJson(Map<String, dynamic> json) {
    return AdminUserLoyaltyDto(
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      history: (json['history']?['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(LoyaltyHistoryItemDto.fromJson)
          .toList(),
    );
  }
}
