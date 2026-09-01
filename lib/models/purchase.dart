enum PurchaseStatus { done, cancelled }

/// A product option offered by Purchase/list_product_purchase — distinct
/// from [Product] because that endpoint returns purchase-specific fields
/// (product_cogs as the suggested buy price) under different keys.
class PurchaseProduct {
  final int id;
  final String code;
  final String name;
  final int cogs;
  final int price;
  final int stock;
  final int? unitId;
  final String? unitName;
  final int? categoryId;
  final String? categoryName;

  const PurchaseProduct({
    required this.id,
    required this.code,
    required this.name,
    required this.cogs,
    required this.price,
    required this.stock,
    this.unitId,
    this.unitName,
    this.categoryId,
    this.categoryName,
  });

  factory PurchaseProduct.fromJson(Map<String, dynamic> json) {
    final unitId = int.tryParse(json['unit_id']?.toString() ?? "");
    final categoryId = int.tryParse(json['category_id']?.toString() ?? "");

    return PurchaseProduct(
      id: _asInt(json['product_id']),
      code: json['product_code']?.toString() ?? "",
      name: json['product_name']?.toString() ?? "",
      cogs: _asInt(json['product_cogs']),
      price: _asInt(json['product_price']),
      stock: _asInt(json['product_stock']),
      unitId: (unitId != null && unitId != 0) ? unitId : null,
      unitName: json['unit_name']?.toString(),
      categoryId: (categoryId != null && categoryId != 0) ? categoryId : null,
      categoryName: json['category_name']?.toString(),
    );
  }
}

class PurchaseItem {
  final int productId;
  final String productName;
  final int price;
  final int qty;
  final int subTotal;

  const PurchaseItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.qty,
    required this.subTotal,
  });

  factory PurchaseItem.fromJson(Map<String, dynamic> json) {
    return PurchaseItem(
      productId: _asInt(json['product_id']),
      productName: json['product_name']?.toString() ?? "",
      price: _asInt(json['price']),
      qty: _asInt(json['qty']),
      subTotal: _asInt(json['sub_total']),
    );
  }
}

class Purchase {
  final int id;
  final String invoiceNumber;
  final DateTime date;
  final String? supplier;
  final String? supplierInvoice;
  final int total;
  final PurchaseStatus status;
  final String createdBy;
  final DateTime? createdAt;
  final String? cancelledBy;
  final DateTime? cancelledAt;

  const Purchase({
    required this.id,
    required this.invoiceNumber,
    required this.date,
    this.supplier,
    this.supplierInvoice,
    required this.total,
    required this.status,
    required this.createdBy,
    this.createdAt,
    this.cancelledBy,
    this.cancelledAt,
  });

  factory Purchase.fromJson(Map<String, dynamic> json) {
    return Purchase(
      id: _asInt(json['id']),
      invoiceNumber: json['inv']?.toString() ?? "",
      date: _parseDate(json['date']),
      supplier: _asNullableString(json['supplier']),
      supplierInvoice: _asNullableString(json['supplier_invoice']),
      total: _asInt(json['total']),
      status: _parseStatus(json['status']),
      createdBy: json['created_by']?.toString() ?? "",
      createdAt: _parseDateTime(json['created_at']),
      cancelledBy: _asNullableString(json['cancelled_by']),
      cancelledAt: _parseDateTime(json['cancelled_at']),
    );
  }
}

/// Detail of a single purchase — same header fields as [Purchase] plus its
/// line items, returned by Purchase/purchase_list when called with a
/// `purchase_id` instead of pagination params.
class PurchaseDetail extends Purchase {
  final List<PurchaseItem> items;

  const PurchaseDetail({
    required super.id,
    required super.invoiceNumber,
    required super.date,
    super.supplier,
    super.supplierInvoice,
    required super.total,
    required super.status,
    required super.createdBy,
    super.createdAt,
    super.cancelledBy,
    super.cancelledAt,
    required this.items,
  });

  factory PurchaseDetail.fromJson(Map<String, dynamic> json) {
    final base = Purchase.fromJson(json);
    final rawItems = json['items'];

    return PurchaseDetail(
      id: base.id,
      invoiceNumber: base.invoiceNumber,
      date: base.date,
      supplier: base.supplier,
      supplierInvoice: base.supplierInvoice,
      total: base.total,
      status: base.status,
      createdBy: base.createdBy,
      createdAt: base.createdAt,
      cancelledBy: base.cancelledBy,
      cancelledAt: base.cancelledAt,
      items: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(PurchaseItem.fromJson)
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

DateTime _parseDate(dynamic value) {
  return DateTime.tryParse(value?.toString() ?? "") ?? DateTime.now();
}

DateTime? _parseDateTime(dynamic value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return null;
  return DateTime.tryParse(text);
}

PurchaseStatus _parseStatus(dynamic value) {
  return value?.toString().toLowerCase() == "done"
      ? PurchaseStatus.done
      : PurchaseStatus.cancelled;
}
