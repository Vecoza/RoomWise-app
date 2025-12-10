class PagedResult<T> {
  final List<T> items;
  final int? totalCount;

  PagedResult({
    required this.items,
    this.totalCount,
  });

  factory PagedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    final list = rawItems
        .map((e) => fromJsonT(e as Map<String, dynamic>))
        .toList();

    final total = json['totalCount'] as int? ?? json['TotalCount'] as int?;

    return PagedResult<T>(
      items: list,
      totalCount: total,
    );
  }
}
