import 'transaction.dart';

/// A cafe/POS sale returned by Cafe/transaction_cafe_list.
class CafeTransaction {
  final int id;
  final String invoiceNumber;
  final DateTime date;
  final String? table;
  final int? customerId;
  final String? customerName;
  final int paymentId;
  final String? paymentName;
  final int? promoId;
  final String? promoName;
  final int subTotal;
  final int discount;
  final int tax;
  final int totalBill;
  final TransactionStatus status;
  final String createdBy;
  final DateTime createdAt;
  final int paidBy;
  final String? cancelledBy;

  const CafeTransaction({
    required this.id,
    required this.invoiceNumber,
    required this.date,
    this.table,
    this.customerId,
    this.customerName,
    required this.paymentId,
    this.paymentName,
    this.promoId,
    this.promoName,
    required this.subTotal,
    required this.discount,
    required this.tax,
    required this.totalBill,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.paidBy,
    this.cancelledBy,
  });

  factory CafeTransaction.fromJson(
    Map<String, dynamic> json, {
    String? paymentName,
    String? promoName,
  }) {
    int asInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? "") ?? 0;
    }

    int? asOptionalId(dynamic value) {
      final id = int.tryParse(value?.toString() ?? "");
      return (id != null && id != 0) ? id : null;
    }

    return CafeTransaction(
      id: asInt(json['id']),
      invoiceNumber: json['inv']?.toString() ?? "",
      date: DateTime.tryParse(json['date']?.toString() ?? "") ?? DateTime.now(),
      table: json['table']?.toString(),
      customerId: asOptionalId(json['customer_id']),
      customerName: json['customer_name']?.toString(),
      paymentId: asInt(json['payment_id']),
      paymentName: paymentName,
      promoId: asOptionalId(json['promo_id']),
      promoName: promoName,
      subTotal: asInt(json['sub_total']),
      discount: asInt(json['discount']),
      tax: asInt(json['tax']),
      totalBill: asInt(json['total_bill']),
      status: json['status']?.toString().toLowerCase() == "done"
          ? TransactionStatus.completed
          : TransactionStatus.canceled,
      createdBy: json['created_by']?.toString() ?? "",
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? "") ??
          DateTime.now(),
      paidBy: asInt(json['paid_by']),
      cancelledBy: json['cancelled_by']?.toString(),
    );
  }
}

class CafeTransactionAddonItem {
  final String name;
  final int quantity;
  final int price;

  const CafeTransactionAddonItem({
    required this.name,
    required this.quantity,
    required this.price,
  });

  factory CafeTransactionAddonItem.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? "") ?? 0;
    }

    return CafeTransactionAddonItem(
      name: json['product_name']?.toString() ?? "",
      quantity: asInt(json['qty']),
      price: asInt(json['price']),
    );
  }
}

class CafeTransactionDetailItem {
  final String name;
  final int quantity;
  final int price;
  final String? note;
  final List<CafeTransactionAddonItem> addons;

  const CafeTransactionDetailItem({
    required this.name,
    required this.quantity,
    required this.price,
    this.note,
    this.addons = const [],
  });

  factory CafeTransactionDetailItem.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? "") ?? 0;
    }

    final rawAddons = json['addons'];

    return CafeTransactionDetailItem(
      name: json['product_name']?.toString() ?? "",
      quantity: asInt(json['qty']),
      price: asInt(json['price']),
      note: json['note']?.toString(),
      addons: rawAddons is List
          ? rawAddons
              .whereType<Map<String, dynamic>>()
              .map(CafeTransactionAddonItem.fromJson)
              .toList()
          : const [],
    );
  }
}

/// Full detail of one cafe transaction, including line items — read via
/// Cafe/transaction_detail, used to reprint a receipt.
class CafeTransactionDetail {
  final int id;
  final String invoiceNumber;
  final DateTime date;
  final String? table;
  final String? customerName;
  final List<CafeTransactionDetailItem> items;
  final int subTotal;
  final int discount;
  final int tax;
  final int totalBill;
  final TransactionStatus status;
  final String createdBy;
  final int paidBy;
  final String paymentMethod;
  final String? cancelledBy;

  const CafeTransactionDetail({
    required this.id,
    required this.invoiceNumber,
    required this.date,
    this.table,
    this.customerName,
    required this.items,
    required this.subTotal,
    required this.discount,
    required this.tax,
    required this.totalBill,
    required this.status,
    required this.createdBy,
    required this.paidBy,
    required this.paymentMethod,
    this.cancelledBy,
  });

  factory CafeTransactionDetail.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? "") ?? 0;
    }

    final rawItems = json['items'];

    return CafeTransactionDetail(
      id: asInt(json['id']),
      invoiceNumber: json['inv']?.toString() ?? "",
      date:
          DateTime.tryParse(json['date']?.toString() ?? "") ?? DateTime.now(),
      table: json['table']?.toString(),
      customerName: json['customer_name']?.toString(),
      items: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(CafeTransactionDetailItem.fromJson)
                .toList()
          : const [],
      subTotal: asInt(json['sub_total']),
      discount: asInt(json['discount']),
      tax: asInt(json['tax']),
      totalBill: asInt(json['total_bill']),
      status: json['status']?.toString().toLowerCase() == "done"
          ? TransactionStatus.completed
          : TransactionStatus.canceled,
      createdBy: json['created_by']?.toString() ?? "",
      paidBy: asInt(json['paid_by']),
      paymentMethod: json['payment_name']?.toString() ?? "-",
      cancelledBy: json['cancelled_by']?.toString(),
    );
  }
}
