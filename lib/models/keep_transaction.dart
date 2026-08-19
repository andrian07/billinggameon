/// A cafe/POS transaction held via Cafe/keep_transaction — an unpaid order
/// parked for later so the cashier can pick it back up at Cafe/select_keep_transaction.
class KeepTransaction {
  final int id;
  final String? name;
  final String invoiceNumber;
  final DateTime date;
  final int? table;
  final int? customerId;
  final int paymentId;
  final int promoId;
  final int subTotal;
  final int discount;
  final int tax;
  final int totalBill;
  final String status;
  final String createdBy;
  final DateTime createdAt;

  const KeepTransaction({
    required this.id,
    this.name,
    required this.invoiceNumber,
    required this.date,
    this.table,
    this.customerId,
    required this.paymentId,
    required this.promoId,
    required this.subTotal,
    required this.discount,
    required this.tax,
    required this.totalBill,
    required this.status,
    required this.createdBy,
    required this.createdAt,
  });

  /// Pass an explicit null to clear [name]; omitting it keeps the current
  /// value — matches the usual copyWith convention for a nullable field.
  KeepTransaction copyWith({String? name, bool clearName = false}) {
    return KeepTransaction(
      id: id,
      name: clearName ? null : (name ?? this.name),
      invoiceNumber: invoiceNumber,
      date: date,
      table: table,
      customerId: customerId,
      paymentId: paymentId,
      promoId: promoId,
      subTotal: subTotal,
      discount: discount,
      tax: tax,
      totalBill: totalBill,
      status: status,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }

  factory KeepTransaction.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString();

    return KeepTransaction(
      id: _asInt(json['id']),
      name: (name == null || name.isEmpty) ? null : name,
      invoiceNumber: json['inv']?.toString() ?? "",
      date: DateTime.tryParse(json['date']?.toString() ?? "") ?? DateTime.now(),
      table: _asIntOrNull(json['table']),
      customerId: _asIntOrNull(json['customer_id']),
      paymentId: _asInt(json['payment_id']),
      promoId: _asInt(json['promo_id']),
      subTotal: _asInt(json['sub_total']),
      discount: _asInt(json['discount']),
      tax: _asInt(json['tax']),
      totalBill: _asInt(json['total_bill']),
      status: json['status']?.toString() ?? "",
      createdBy: json['created_by']?.toString() ?? "",
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? "") ??
          DateTime.now(),
    );
  }
}

class KeepTransactionItem {
  final int productId;
  final String productName;
  final int productPrice;
  final int quantity;
  final int subTotal;
  final String? note;

  const KeepTransactionItem({
    required this.productId,
    required this.productName,
    required this.productPrice,
    required this.quantity,
    required this.subTotal,
    this.note,
  });

  factory KeepTransactionItem.fromJson(Map<String, dynamic> json) {
    final note = json['note']?.toString();

    return KeepTransactionItem(
      productId: _asInt(json['product_id']),
      productName: json['product_name']?.toString() ?? "",
      productPrice: _asInt(json['product_price']),
      quantity: _asInt(json['qty']),
      subTotal: _asInt(json['sub_total']),
      note: (note == null || note.isEmpty) ? null : note,
    );
  }
}

/// Detail of a single held transaction, including the line items that get
/// resubmitted to Cafe/save_transaction_cafe when the cashier actually pays.
class KeepTransactionDetail extends KeepTransaction {
  final List<KeepTransactionItem> items;

  const KeepTransactionDetail({
    required super.id,
    super.name,
    required super.invoiceNumber,
    required super.date,
    super.table,
    super.customerId,
    required super.paymentId,
    required super.promoId,
    required super.subTotal,
    required super.discount,
    required super.tax,
    required super.totalBill,
    required super.status,
    required super.createdBy,
    required super.createdAt,
    required this.items,
  });

  factory KeepTransactionDetail.fromJson(Map<String, dynamic> json) {
    final base = KeepTransaction.fromJson(json);
    final rawItems = json['items'];

    return KeepTransactionDetail(
      id: base.id,
      name: base.name,
      invoiceNumber: base.invoiceNumber,
      date: base.date,
      table: base.table,
      customerId: base.customerId,
      paymentId: base.paymentId,
      promoId: base.promoId,
      subTotal: base.subTotal,
      discount: base.discount,
      tax: base.tax,
      totalBill: base.totalBill,
      status: base.status,
      createdBy: base.createdBy,
      createdAt: base.createdAt,
      items: rawItems is List
          ? [
              for (final item in rawItems)
                if (item is Map<String, dynamic>)
                  KeepTransactionItem.fromJson(item),
            ]
          : const [],
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? "") ?? 0;
}

int? _asIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}
