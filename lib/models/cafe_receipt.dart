class CafeReceiptAddon {
  final String name;
  final int quantity;
  final int price;

  const CafeReceiptAddon({
    required this.name,
    required this.quantity,
    required this.price,
  });

  int get lineTotal => price * quantity;
}

class CafeReceiptItem {
  final String name;
  final int quantity;
  final int price;
  final String? note;
  final List<CafeReceiptAddon> addons;

  const CafeReceiptItem({
    required this.name,
    required this.quantity,
    required this.price,
    this.note,
    this.addons = const [],
  });

  int get lineTotal =>
      price * quantity + addons.fold(0, (sum, a) => sum + a.lineTotal);
}

class CafeReceipt {
  final String businessName;
  final String businessAddress;
  final String invoiceNumber;
  final DateTime date;
  final String? table;
  final String? customerName;
  final List<CafeReceiptItem> items;
  final int subtotal;
  final int discountPercent;
  final int discountAmount;
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
    this.customerName,
    required this.items,
    required this.subtotal,
    this.discountPercent = 0,
    this.discountAmount = 0,
    required this.tax,
    required this.total,
    required this.paymentMethod,
    required this.cashierName,
    this.isReprint = false,
  });
}
