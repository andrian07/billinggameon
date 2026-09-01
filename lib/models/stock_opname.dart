/// A stock-tracked product offered by Opname/product_list, with its current
/// system stock — the baseline the cashier/owner counts against.
class OpnameProduct {
  final int id;
  final String code;
  final String name;
  final int systemStock;
  final int? unitId;
  final String? unitName;
  final int? categoryId;
  final String? categoryName;

  const OpnameProduct({
    required this.id,
    required this.code,
    required this.name,
    required this.systemStock,
    this.unitId,
    this.unitName,
    this.categoryId,
    this.categoryName,
  });

  factory OpnameProduct.fromJson(Map<String, dynamic> json) {
    final unitId = int.tryParse(json['unit_id']?.toString() ?? "");
    final categoryId = int.tryParse(json['category_id']?.toString() ?? "");

    return OpnameProduct(
      id: _asInt(json['product_id']),
      code: json['product_code']?.toString() ?? "",
      name: json['product_name']?.toString() ?? "",
      systemStock: _asInt(json['product_stock']),
      unitId: (unitId != null && unitId != 0) ? unitId : null,
      unitName: json['unit_name']?.toString(),
      categoryId: (categoryId != null && categoryId != 0) ? categoryId : null,
      categoryName: json['category_name']?.toString(),
    );
  }
}

class StockOpnameItem {
  final int productId;
  final String productName;
  final int systemStock;
  final int physicalStock;
  final int difference;

  const StockOpnameItem({
    required this.productId,
    required this.productName,
    required this.systemStock,
    required this.physicalStock,
    required this.difference,
  });

  factory StockOpnameItem.fromJson(Map<String, dynamic> json) {
    return StockOpnameItem(
      productId: _asInt(json['product_id']),
      productName: json['product_name']?.toString() ?? "",
      systemStock: _asInt(json['system_stock']),
      physicalStock: _asInt(json['physical_stock']),
      difference: _asInt(json['difference']),
    );
  }
}

class StockOpname {
  final int id;
  final String invoiceNumber;
  final DateTime date;
  final String? note;
  final String createdBy;
  final DateTime? createdAt;

  const StockOpname({
    required this.id,
    required this.invoiceNumber,
    required this.date,
    this.note,
    required this.createdBy,
    this.createdAt,
  });

  factory StockOpname.fromJson(Map<String, dynamic> json) {
    return StockOpname(
      id: _asInt(json['id']),
      invoiceNumber: json['inv']?.toString() ?? "",
      date: DateTime.tryParse(json['date']?.toString() ?? "") ?? DateTime.now(),
      note: _asNullableString(json['note']),
      createdBy: json['created_by']?.toString() ?? "",
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ""),
    );
  }
}

/// Detail of a single opname — same header fields as [StockOpname] plus its
/// counted line items, returned by Opname/opname_list when called with an
/// `opname_id` instead of pagination params.
class StockOpnameDetail extends StockOpname {
  final List<StockOpnameItem> items;

  const StockOpnameDetail({
    required super.id,
    required super.invoiceNumber,
    required super.date,
    super.note,
    required super.createdBy,
    super.createdAt,
    required this.items,
  });

  factory StockOpnameDetail.fromJson(Map<String, dynamic> json) {
    final base = StockOpname.fromJson(json);
    final rawItems = json['items'];

    return StockOpnameDetail(
      id: base.id,
      invoiceNumber: base.invoiceNumber,
      date: base.date,
      note: base.note,
      createdBy: base.createdBy,
      createdAt: base.createdAt,
      items: rawItems is List
          ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(StockOpnameItem.fromJson)
              .toList()
          : const [],
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? "") ?? 0;
}

String? _asNullableString(dynamic value) {
  final text = value?.toString();
  return (text == null || text.isEmpty) ? null : text;
}
