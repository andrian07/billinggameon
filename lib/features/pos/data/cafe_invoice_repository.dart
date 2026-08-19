import '../../../core/constants/business_info.dart';
import '../../../models/cafe_receipt.dart';
import '../../../models/cart_item.dart';
import '../widgets/cafe_payment_dialog.dart';

/// Builds cafe/POS receipt data for the receipt printer, from the cart and
/// the payment result — [payment.transactionCafeId] anchors the printed
/// invoice number to the real backend record.
class CafeInvoiceRepository {
  Future<CafeReceipt> generateInvoice({
    required List<CartItem> items,
    required int subtotal,
    required CafePaymentResult payment,
    required String cashierName,
  }) {
    final now = DateTime.now();

    return Future.value(
      CafeReceipt(
        businessName: BusinessInfo.name,
        businessAddress: BusinessInfo.address,
        invoiceNumber: _buildInvoiceNumber(now, payment.transactionCafeId),
        date: now,
        table: payment.table != null ? "Meja ${payment.table}" : "Takeaway",
        items: [
          for (final item in items)
            CafeReceiptItem(
              name: item.product.name,
              quantity: item.quantity,
              price: item.product.price,
              note: item.note,
            ),
        ],
        subtotal: subtotal,
        tax: payment.tax,
        total: subtotal + payment.tax,
        paymentMethod: payment.paymentMethodName,
        cashierName: cashierName,
      ),
    );
  }

  String _buildInvoiceNumber(DateTime now, int transactionCafeId) {
    String two(int n) => n.toString().padLeft(2, '0');
    final date = "${now.year}-${two(now.month)}-${two(now.day)}";
    return "INV/${BusinessInfo.outletCode}/$date/"
        "${transactionCafeId.toString().padLeft(10, '0')}";
  }
}
