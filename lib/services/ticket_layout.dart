import 'package:unified_esc_pos_printer/unified_esc_pos_printer.dart';

import '../core/utils/formatters.dart';

/// Shared layout pieces for every printed receipt (table billing, cafe/POS,
/// tutup kas) so they read as one consistent design instead of three
/// independently hand-rolled layouts.
///
/// Bold is only ever applied via full-line [Ticket.text] calls here, never
/// inside a [Ticket.row] column: the plugin reinforces mid-line bold with a
/// bare-CR overstrike meant to overlap the same printed line on printers
/// that ignore inline ESC E, but this printer's firmware treats that CR as
/// a newline instead — turning the "reinforcement" into a literal
/// duplicate line. [grandTotal] gets its emphasis from size instead, which
/// is safe.
class TicketLayout {
  TicketLayout._();

  static void header(
    Ticket ticket, {
    required String businessName,
    required String businessAddress,
    required String invoiceNumber,
    required DateTime issuedAt,
    bool isReprint = false,
  }) {
    ticket.text(
      businessName,
      align: PrintAlign.center,
      style: const PrintTextStyle(bold: true),
    );
    ticket.text(businessAddress, align: PrintAlign.center);
    ticket.separator(char: '=', linesAfter: 1);
    ticket.text(
      invoiceNumber,
      align: PrintAlign.center,
      style: const PrintTextStyle(bold: true),
    );
    ticket.text(
      "${formatFullDate(issuedAt)}  ${formatClock(issuedAt)}",
      align: PrintAlign.center,
    );
    if (isReprint) {
      ticket.text(
        "*** PRINT ULANG ***",
        align: PrintAlign.center,
        style: const PrintTextStyle(bold: true),
      );
    }
    ticket.separator(char: '=', linesAfter: 1);
  }

  /// A plain label/value row — never bold, see class doc.
  static void row(Ticket ticket, String label, String value) {
    ticket.row([
      PrintColumn(text: label, flex: 4),
      PrintColumn(text: value, flex: 5, align: PrintAlign.right),
    ]);
  }

  static void sectionTitle(Ticket ticket, String title) {
    ticket.feed(1);
    ticket.text(title, style: const PrintTextStyle(bold: true));
  }

  /// The final amount, set apart and enlarged so it's unmistakable —
  /// entirely via full-line text, never a row (see class doc).
  static void grandTotal(Ticket ticket, String label, int amount) {
    ticket.separator(char: '=', linesAfter: 1);
    ticket.text(label, style: const PrintTextStyle(bold: true));
    ticket.text(
      formatCurrency(amount),
      align: PrintAlign.right,
      style: const PrintTextStyle(
        bold: true,
        height: TextSize.size2,
        width: TextSize.size2,
      ),
    );
    ticket.separator(char: '=', linesAfter: 1);
  }

  static void footer(Ticket ticket, String cashierName) {
    row(ticket, "Kasir", cashierName);
    ticket.feed(1);
    ticket.text("Terima kasih atas kunjungan Anda", align: PrintAlign.center);
    ticket.feed(3);
    ticket.cut();
  }
}
