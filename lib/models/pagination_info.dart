class PaginationInfo {
  final int currentPage;
  final int perPage;
  final int totalItems;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPrevPage;

  const PaginationInfo({
    required this.currentPage,
    required this.perPage,
    required this.totalItems,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPrevPage,
  });

  static const empty = PaginationInfo(
    currentPage: 1,
    perPage: 10,
    totalItems: 0,
    totalPages: 1,
    hasNextPage: false,
    hasPrevPage: false,
  );

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic value, int fallback) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? "") ?? fallback;
    }

    bool asBool(dynamic value) {
      if (value is bool) return value;
      return value?.toString() == "true" || value?.toString() == "1";
    }

    return PaginationInfo(
      currentPage: asInt(json['current_page'], 1),
      perPage: asInt(json['per_page'], 10),
      totalItems: asInt(json['total_items'], 0),
      totalPages: asInt(json['total_pages'], 1),
      hasNextPage: asBool(json['has_next_page']),
      hasPrevPage: asBool(json['has_prev_page']),
    );
  }
}
