import '../../../core/constants/business_info.dart';
import '../../../models/pool_table.dart';
import '../../../models/receipt.dart';
import '../widgets/payment_dialog.dart';

/// Builds invoice data for the receipt printer, from the table and the
/// payment result — [PaymentResult] already carries the real subtotal,
/// promo discount, total, and [PaymentResult.transactionId] (the backend's
/// real `transaction_id`) that anchors the printed invoice number to the
/// actual stored record, same pattern as [CafeInvoiceRepository].
class InvoiceRepository {
  Future<Receipt> generateInvoice(
    PoolTable table,
    PaymentResult payment, {
    required String cashierName,
  }) {
    final now = DateTime.now();
    final start = table.startAt ?? now;
    final duration = now.difference(start);

    return Future.value(
      Receipt(
        businessName: BusinessInfo.name,
        businessAddress: BusinessInfo.address,
        invoiceNumber: _buildInvoiceNumber(now, payment.transactionId),
        tableLabel: "${_tableNumber(table)} - ${_sessionLabel(table)}",
        periods: const [],
        date: now,
        startAt: start,
        endAt: now,
        totalDuration: duration.isNegative ? Duration.zero : duration,
        subtotal: payment.subtotal,
        discountAmount: payment.discountAmount,
        promoName: payment.promo,
        grandTotal: payment.total,
        paymentMethod: payment.paymentMethod,
        cashierName: cashierName,
      ),
    );
  }

  String _buildInvoiceNumber(DateTime now, int transactionId) {
    String two(int n) => n.toString().padLeft(2, '0');
    final date = "${now.year}-${two(now.month)}-${two(now.day)}";
    return "INV/${BusinessInfo.outletCode}/$date/"
        "${transactionId.toString().padLeft(10, '0')}";
  }

  String _tableNumber(PoolTable table) =>
      table.name.replaceAll(RegExp(r'[^0-9]'), '');

  String _sessionLabel(PoolTable table) {
    switch (table.sessionType) {
      case SessionType.timer:
        return "Timer";
      case SessionType.reguler:
        return "Reguler";
      case null:
        return "-";
    }
  }
}
