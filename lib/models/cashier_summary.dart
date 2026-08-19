/// One payment method's slice of a channel's total, e.g. how much of
/// today's billing revenue came in as CASH vs Transfer.
class CashierPaymentBreakdown {
  final int paymentId;
  final String paymentName;
  final int totalTransaction;
  final int invoiceCount;

  const CashierPaymentBreakdown({
    required this.paymentId,
    required this.paymentName,
    required this.totalTransaction,
    required this.invoiceCount,
  });

  factory CashierPaymentBreakdown.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? "") ?? 0;
    }

    return CashierPaymentBreakdown(
      paymentId: asInt(json['payment_id']),
      paymentName: json['payment_name']?.toString() ?? "",
      totalTransaction: asInt(json['total_transaksi']),
      invoiceCount: asInt(json['jumlah_nota']),
    );
  }
}

/// One channel's (billing or cafe) transaction count/total for a cashier's
/// "tutup kas" (close register) summary, broken down per payment method.
class CashierTransactionSummary {
  final int totalTransaction;
  final int invoiceCount;
  final List<CashierPaymentBreakdown> byPayment;

  const CashierTransactionSummary({
    required this.totalTransaction,
    required this.invoiceCount,
    this.byPayment = const [],
  });

  static const empty = CashierTransactionSummary(
    totalTransaction: 0,
    invoiceCount: 0,
  );

  factory CashierTransactionSummary.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? "") ?? 0;
    }

    final rawByPayment = json['by_payment'];

    return CashierTransactionSummary(
      totalTransaction: asInt(json['total_transaksi']),
      invoiceCount: asInt(json['jumlah_nota']),
      byPayment: rawByPayment is List
          ? rawByPayment
                .whereType<Map<String, dynamic>>()
                .map(CashierPaymentBreakdown.fromJson)
                .toList()
          : const [],
    );
  }
}

/// One cafe product's total quantity sold, for the "Cetak Cafe" item
/// breakdown printed from Tutup Kas.
class CafeItemSold {
  final String productName;
  final int quantity;

  const CafeItemSold({required this.productName, required this.quantity});

  factory CafeItemSold.fromJson(Map<String, dynamic> json) {
    final qty = json['qty'];
    return CafeItemSold(
      productName: json['product_name']?.toString() ?? "",
      quantity: qty is int ? qty : int.tryParse(qty?.toString() ?? "") ?? 0,
    );
  }
}

/// Today's transaction summary for a logged-in cashier, combining billing
/// (pool table), cafe/POS sales, and saldo top-ups — read via
/// Report/get_transaction_today_by_cashier for the "Tutup Kas" flow.
class CashierClosingSummary {
  final DateTime businessDate;
  final int userId;
  final CashierTransactionSummary billing;
  final CashierTransactionSummary cafe;
  final CashierTransactionSummary saldo;
  final List<CafeItemSold> cafeItems;

  const CashierClosingSummary({
    required this.businessDate,
    required this.userId,
    required this.billing,
    required this.cafe,
    this.saldo = CashierTransactionSummary.empty,
    this.cafeItems = const [],
  });

  /// Billing + cafe sales only — saldo top-ups are deposits, not revenue,
  /// so they're shown as their own section rather than folded into this.
  int get totalTransaction => billing.totalTransaction + cafe.totalTransaction;

  int get totalInvoiceCount =>
      billing.invoiceCount + cafe.invoiceCount + saldo.invoiceCount;

  factory CashierClosingSummary.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? "") ?? 0;
    }

    final billingJson = json['billing'];
    final cafeJson = json['cafe'];
    final saldoJson = json['saldo'];
    final cafeItemsJson = json['cafe_items'];

    return CashierClosingSummary(
      businessDate:
          DateTime.tryParse(json['business_date']?.toString() ?? "") ??
          DateTime.now(),
      userId: asInt(json['user_id']),
      billing: billingJson is Map<String, dynamic>
          ? CashierTransactionSummary.fromJson(billingJson)
          : CashierTransactionSummary.empty,
      cafe: cafeJson is Map<String, dynamic>
          ? CashierTransactionSummary.fromJson(cafeJson)
          : CashierTransactionSummary.empty,
      saldo: saldoJson is Map<String, dynamic>
          ? CashierTransactionSummary.fromJson(saldoJson)
          : CashierTransactionSummary.empty,
      cafeItems: cafeItemsJson is List
          ? cafeItemsJson
                .whereType<Map<String, dynamic>>()
                .map(CafeItemSold.fromJson)
                .toList()
          : const [],
    );
  }
}
