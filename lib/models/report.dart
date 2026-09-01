/// Shared invoice-count/total shape returned by Report/billing_report and
/// Report/cafe_report under `summary`.
class ReportSummary {
  final int invoiceCount;
  final int totalSubTotal;
  final int totalDiscount;
  final int totalTax;
  final int totalBill;

  const ReportSummary({
    required this.invoiceCount,
    required this.totalSubTotal,
    required this.totalDiscount,
    required this.totalTax,
    required this.totalBill,
  });

  static const empty = ReportSummary(
    invoiceCount: 0,
    totalSubTotal: 0,
    totalDiscount: 0,
    totalTax: 0,
    totalBill: 0,
  );

  factory ReportSummary.fromJson(Map<String, dynamic> json) {
    return ReportSummary(
      invoiceCount: _asInt(json['jumlah_nota']),
      totalSubTotal: _asInt(json['total_sub_total']),
      totalDiscount: _asInt(json['total_discount']),
      totalTax: _asInt(json['total_tax']),
      totalBill: _asInt(json['total_bill']),
    );
  }
}

class BillingReportRow {
  final int id;
  final String invoiceNumber;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String? memberName;
  final String kasirName;
  final String paymentName;
  final int subTotal;
  final int discount;
  final int tax;
  final int totalBill;
  final String status;

  const BillingReportRow({
    required this.id,
    required this.invoiceNumber,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.memberName,
    required this.kasirName,
    required this.paymentName,
    required this.subTotal,
    required this.discount,
    required this.tax,
    required this.totalBill,
    required this.status,
  });

  factory BillingReportRow.fromJson(Map<String, dynamic> json) {
    final memberName = json['member_name']?.toString();

    return BillingReportRow(
      id: _asInt(json['id']),
      invoiceNumber: json['inv']?.toString() ?? "",
      date: DateTime.tryParse(json['date']?.toString() ?? "") ?? DateTime.now(),
      startTime: json['start_time']?.toString() ?? "-",
      endTime: json['end_time']?.toString() ?? "-",
      memberName: (memberName == null || memberName.isEmpty)
          ? null
          : memberName,
      kasirName: json['kasir_name']?.toString() ?? "",
      paymentName: json['payment_name']?.toString() ?? "-",
      subTotal: _asInt(json['sub_total']),
      discount: _asInt(json['discount']),
      tax: _asInt(json['tax']),
      totalBill: _asInt(json['total_bill']),
      status: json['status']?.toString() ?? "",
    );
  }
}

class BillingReportResult {
  final List<BillingReportRow> rows;
  final ReportSummary summary;

  const BillingReportResult({required this.rows, required this.summary});

  factory BillingReportResult.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final rawSummary = json['summary'];

    return BillingReportResult(
      rows: rawData is List
          ? rawData
                .whereType<Map<String, dynamic>>()
                .map(BillingReportRow.fromJson)
                .toList()
          : const [],
      summary: rawSummary is Map<String, dynamic>
          ? ReportSummary.fromJson(rawSummary)
          : ReportSummary.empty,
    );
  }
}

class CafeReportRow {
  final int id;
  final String invoiceNumber;
  final DateTime date;
  final DateTime time;
  final String? memberName;
  final String kasirName;
  final String paymentName;
  final int subTotal;
  final int discount;
  final int tax;
  final int totalBill;
  final String status;
  final String? cancelledBy;

  const CafeReportRow({
    required this.id,
    required this.invoiceNumber,
    required this.date,
    required this.time,
    this.memberName,
    required this.kasirName,
    required this.paymentName,
    required this.subTotal,
    required this.discount,
    required this.tax,
    required this.totalBill,
    required this.status,
    this.cancelledBy,
  });

  factory CafeReportRow.fromJson(Map<String, dynamic> json) {
    final memberName = json['member_name']?.toString();
    final date = DateTime.tryParse(json['date']?.toString() ?? "") ??
        DateTime.now();

    return CafeReportRow(
      id: _asInt(json['id']),
      invoiceNumber: json['inv']?.toString() ?? "",
      date: date,
      time: DateTime.tryParse(json['time']?.toString() ?? "") ?? date,
      memberName: (memberName == null || memberName.isEmpty)
          ? null
          : memberName,
      kasirName: json['kasir_name']?.toString() ?? "",
      paymentName: json['payment_name']?.toString() ?? "-",
      subTotal: _asInt(json['sub_total']),
      discount: _asInt(json['discount']),
      tax: _asInt(json['tax']),
      totalBill: _asInt(json['total_bill']),
      status: json['status']?.toString() ?? "",
      cancelledBy: json['cancelled_by']?.toString(),
    );
  }
}

class CafeReportResult {
  final List<CafeReportRow> rows;
  final ReportSummary summary;

  const CafeReportResult({required this.rows, required this.summary});

  factory CafeReportResult.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final rawSummary = json['summary'];

    return CafeReportResult(
      rows: rawData is List
          ? rawData
                .whereType<Map<String, dynamic>>()
                .map(CafeReportRow.fromJson)
                .toList()
          : const [],
      summary: rawSummary is Map<String, dynamic>
          ? ReportSummary.fromJson(rawSummary)
          : ReportSummary.empty,
    );
  }
}

/// Row shape for Report/saldo_report — a saldo top-up read for reporting,
/// distinct from SaldoTransaction (Billing/transaction_saldo_list) even
/// though they describe the same kind of record.
class SaldoReportRow {
  final int id;
  final String invoiceNumber;
  final DateTime time;
  final String? memberName;
  final String kasirName;
  final String paymentName;
  final int nominal;
  final int discount;
  final int pay;
  final String status;

  const SaldoReportRow({
    required this.id,
    required this.invoiceNumber,
    required this.time,
    this.memberName,
    required this.kasirName,
    required this.paymentName,
    required this.nominal,
    required this.discount,
    required this.pay,
    required this.status,
  });

  factory SaldoReportRow.fromJson(Map<String, dynamic> json) {
    final memberName = json['member_name']?.toString();

    return SaldoReportRow(
      id: _asInt(json['id']),
      invoiceNumber: json['inv']?.toString() ?? "",
      time: DateTime.tryParse(json['time']?.toString() ?? "") ?? DateTime.now(),
      memberName: (memberName == null || memberName.isEmpty)
          ? null
          : memberName,
      kasirName: json['kasir_name']?.toString() ?? "",
      paymentName: json['payment_name']?.toString() ?? "-",
      nominal: _asInt(json['nominal']),
      discount: _asInt(json['discount_pay']),
      pay: _asInt(json['pay']),
      status: json['status']?.toString() ?? "",
    );
  }
}

/// Summary shape for Report/saldo_report — same idea as [ReportSummary] but
/// with saldo-specific field names (nominal/pay instead of subtotal/bill).
class SaldoReportSummary {
  final int invoiceCount;
  final int totalNominal;
  final int totalDiscount;
  final int totalPay;

  const SaldoReportSummary({
    required this.invoiceCount,
    required this.totalNominal,
    required this.totalDiscount,
    required this.totalPay,
  });

  static const empty = SaldoReportSummary(
    invoiceCount: 0,
    totalNominal: 0,
    totalDiscount: 0,
    totalPay: 0,
  );

  factory SaldoReportSummary.fromJson(Map<String, dynamic> json) {
    return SaldoReportSummary(
      invoiceCount: _asInt(json['jumlah_nota']),
      totalNominal: _asInt(json['total_nominal']),
      totalDiscount: _asInt(json['total_discount_pay']),
      totalPay: _asInt(json['total_pay']),
    );
  }
}

class SaldoReportResult {
  final List<SaldoReportRow> rows;
  final SaldoReportSummary summary;

  const SaldoReportResult({required this.rows, required this.summary});

  factory SaldoReportResult.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final rawSummary = json['summary'];

    return SaldoReportResult(
      rows: rawData is List
          ? rawData
                .whereType<Map<String, dynamic>>()
                .map(SaldoReportRow.fromJson)
                .toList()
          : const [],
      summary: rawSummary is Map<String, dynamic>
          ? SaldoReportSummary.fromJson(rawSummary)
          : SaldoReportSummary.empty,
    );
  }
}

class StockReportRow {
  final String productCode;
  final String productName;
  final int totalStock;

  const StockReportRow({
    required this.productCode,
    required this.productName,
    required this.totalStock,
  });

  factory StockReportRow.fromJson(Map<String, dynamic> json) {
    return StockReportRow(
      productCode: json['product_code']?.toString() ?? "",
      productName: json['product_name']?.toString() ?? "",
      totalStock: _asInt(json['total_stock']),
    );
  }
}

class PurchaseReportRow {
  final int id;
  final String invoiceNumber;
  final DateTime date;
  final String? supplier;
  final String? supplierInvoice;
  final int subTotal;
  final int discount;
  final int total;
  final String status;
  final String createdBy;
  final String? cancelledBy;

  const PurchaseReportRow({
    required this.id,
    required this.invoiceNumber,
    required this.date,
    this.supplier,
    this.supplierInvoice,
    required this.subTotal,
    required this.discount,
    required this.total,
    required this.status,
    required this.createdBy,
    this.cancelledBy,
  });

  factory PurchaseReportRow.fromJson(Map<String, dynamic> json) {
    return PurchaseReportRow(
      id: _asInt(json['id']),
      invoiceNumber: json['inv']?.toString() ?? "",
      date: DateTime.tryParse(json['date']?.toString() ?? "") ?? DateTime.now(),
      supplier: json['supplier']?.toString(),
      supplierInvoice: json['supplier_invoice']?.toString(),
      subTotal: _asInt(json['sub_total']),
      discount: _asInt(json['discount']),
      total: _asInt(json['total']),
      status: json['status']?.toString() ?? "",
      createdBy: json['created_by']?.toString() ?? "",
      cancelledBy: json['cancelled_by']?.toString(),
    );
  }
}

/// Purchase report totals — a subset of [ReportSummary]'s shape (no tax,
/// since purchases don't have one) returned by Report/purchase_report.
class PurchaseReportSummary {
  final int invoiceCount;
  final int totalSubTotal;
  final int totalDiscount;
  final int totalBill;

  const PurchaseReportSummary({
    required this.invoiceCount,
    required this.totalSubTotal,
    required this.totalDiscount,
    required this.totalBill,
  });

  static const empty = PurchaseReportSummary(
    invoiceCount: 0,
    totalSubTotal: 0,
    totalDiscount: 0,
    totalBill: 0,
  );

  factory PurchaseReportSummary.fromJson(Map<String, dynamic> json) {
    return PurchaseReportSummary(
      invoiceCount: _asInt(json['jumlah_nota']),
      totalSubTotal: _asInt(json['total_sub_total']),
      totalDiscount: _asInt(json['total_discount']),
      totalBill: _asInt(json['total_bill']),
    );
  }
}

class PurchaseReportResult {
  final List<PurchaseReportRow> rows;
  final PurchaseReportSummary summary;

  const PurchaseReportResult({required this.rows, required this.summary});

  factory PurchaseReportResult.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final rawSummary = json['summary'];

    return PurchaseReportResult(
      rows: rawData is List
          ? rawData
                .whereType<Map<String, dynamic>>()
                .map(PurchaseReportRow.fromJson)
                .toList()
          : const [],
      summary: rawSummary is Map<String, dynamic>
          ? PurchaseReportSummary.fromJson(rawSummary)
          : PurchaseReportSummary.empty,
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? "") ?? 0;
}
