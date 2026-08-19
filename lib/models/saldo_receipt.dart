/// Printable nota for a member saldo top-up, built from the
/// Setting/saldo_list package the cashier picked in the "Tambah Saldo"
/// dialog — see SaldoOption for where nominal/price/discount come from.
class SaldoReceipt {
  final String businessName;
  final String businessAddress;
  final String invoiceNumber;
  final String customerName;
  final int nominal;
  final int discount;
  final int price;
  final String paymentMethod;
  final DateTime date;
  final String cashierName;

  const SaldoReceipt({
    required this.businessName,
    required this.businessAddress,
    required this.invoiceNumber,
    required this.customerName,
    required this.nominal,
    required this.discount,
    required this.price,
    required this.paymentMethod,
    required this.date,
    required this.cashierName,
  });
}
