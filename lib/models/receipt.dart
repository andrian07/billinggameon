class ReceiptPeriod {
  final String label;
  final Duration duration;
  final int cost;

  const ReceiptPeriod({
    required this.label,
    required this.duration,
    required this.cost,
  });
}

class Receipt {
  final String businessName;
  final String businessAddress;
  final String invoiceNumber;
  final String tableLabel;
  final List<ReceiptPeriod> periods;
  final DateTime date;
  final DateTime startAt;
  final DateTime endAt;
  final Duration totalDuration;
  final int subtotal;
  final int discountAmount;
  final String? promoName;
  final int grandTotal;
  final String paymentMethod;
  final String cashierName;
  final bool isReprint;

  const Receipt({
    required this.businessName,
    required this.businessAddress,
    required this.invoiceNumber,
    required this.tableLabel,
    required this.periods,
    required this.date,
    required this.startAt,
    required this.endAt,
    required this.totalDuration,
    required this.subtotal,
    required this.discountAmount,
    this.promoName,
    required this.grandTotal,
    required this.paymentMethod,
    required this.cashierName,
    this.isReprint = false,
  });
}
