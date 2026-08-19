class CafeReceiptItem {
  final String name;
  final int quantity;
  final int price;
  final String? note;

  const CafeReceiptItem({
    required this.name,
    required this.quantity,
    required this.price,
    this.note,
  });

  int get lineTotal => price * quantity;
}

class CafeReceipt {
  final String businessName;
  final String businessAddress;
  final String invoiceNumber;
  final DateTime date;
  final String? table;
  final List<CafeReceiptItem> items;
  final int subtotal;
  final int tax;
  final int total;
  final String paymentMethod;
  final String cashierName;
  final bool isReprint;

  const CafeReceipt({
    required this.businessName,
    required this.businessAddress,
    required this.invoiceNumber,
    required this.date,
    this.table,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.paymentMethod,
    required this.cashierName,
    this.isReprint = false,
  });
}
