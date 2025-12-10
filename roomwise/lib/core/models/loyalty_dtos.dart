class LoyaltyBalanceDto {
  final int balance;

  LoyaltyBalanceDto({required this.balance});

  factory LoyaltyBalanceDto.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      final raw = json['balance'] ?? json['Balance'] ?? 0;
      return LoyaltyBalanceDto(balance: (raw as num).toInt());
    }
    if (json is num) {
      return LoyaltyBalanceDto(balance: json.toInt());
    }
    return LoyaltyBalanceDto(balance: 0);
  }
}

class LoyaltyHistoryItemDto {
  final String id;
  final DateTime createdAt;
  final int delta; // positive = earned, negative = redeemed
  final String? reason;
  final String? reservationCode;

  LoyaltyHistoryItemDto({
    required this.id,
    required this.createdAt,
    required this.delta,
    this.reason,
    this.reservationCode,
  });

  factory LoyaltyHistoryItemDto.fromJson(Map<String, dynamic> json) {
    final created =
        DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.tryParse(json['createdDate'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
    return LoyaltyHistoryItemDto(
      id: json['id']?.toString() ?? '',
      createdAt: created,
      delta: (json['delta'] as num?)?.toInt() ?? 0,
      reason: json['reason'] as String?,
      reservationCode: json['reservationCode'] as String? ??
          json['reservationId']?.toString(),
    );
  }
}

class LoyaltyHistoryPageDto {
  final List<LoyaltyHistoryItemDto> items;
  final int page;
  final int pageSize;
  final int totalCount;

  LoyaltyHistoryPageDto({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
  });

  factory LoyaltyHistoryPageDto.fromJson(dynamic json) {
    if (json is List<dynamic>) {
      final list = json
          .whereType<Map<String, dynamic>>()
          .map(LoyaltyHistoryItemDto.fromJson)
          .toList();
      return LoyaltyHistoryPageDto(
        items: list,
        page: 1,
        pageSize: list.length,
        totalCount: list.length,
      );
    }

    final map = json as Map<String, dynamic>;
    final itemsJson = map['items'] as List<dynamic>? ?? const [];

    final list = itemsJson
        .whereType<Map<String, dynamic>>()
        .map(LoyaltyHistoryItemDto.fromJson)
        .toList();

    return LoyaltyHistoryPageDto(
      items: list,
      page: map['page'] as int? ?? 1,
      pageSize: map['pageSize'] as int? ?? list.length,
      totalCount: map['totalCount'] as int? ?? list.length,
    );
  }
}
