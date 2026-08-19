import 'transaction.dart';

/// A saldo top-up returned by Billing/transaction_saldo_list. `nominal` is
/// the amount credited to the member's balance; `pay` is what was actually
/// charged after `discount` — `pay` is the figure that belongs in revenue
/// totals (e.g. the "Total Transaksi Saldo" stat on the Meja page and the
/// "Tutup Kas" summary), not `nominal`.
class SaldoTransaction {
  final int id;
  final String invoiceNumber;
  final int customerId;
  final String customerName;
  final int saldoId;
  final int nominal;
  final int pay;
  final int discount;
  final int paymentId;
  final String paymentName;
  final TransactionStatus status;
  final String createdBy;
  final DateTime createdAt;
  final int paidBy;

  const SaldoTransaction({
    required this.id,
    required this.invoiceNumber,
    required this.customerId,
    required this.customerName,
    required this.saldoId,
    required this.nominal,
    required this.pay,
    required this.discount,
    required this.paymentId,
    required this.paymentName,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.paidBy,
  });

  factory SaldoTransaction.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? "") ?? 0;
    }

    return SaldoTransaction(
      id: asInt(json['id']),
      invoiceNumber: json['inv']?.toString() ?? "",
      customerId: asInt(json['customer_id']),
      customerName: json['customer_name']?.toString() ?? "",
      saldoId: asInt(json['ms_saldo_id']),
      nominal: asInt(json['nominal']),
      pay: asInt(json['pay']),
      discount: asInt(json['discount_pay']),
      paymentId: asInt(json['payment_id']),
      paymentName: json['payment_name']?.toString() ?? "",
      status: json['status']?.toString().toLowerCase() == "done"
          ? TransactionStatus.completed
          : TransactionStatus.canceled,
      createdBy: json['created_by']?.toString() ?? "",
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? "") ??
          DateTime.now(),
      paidBy: asInt(json['paid_by']),
    );
  }
}
