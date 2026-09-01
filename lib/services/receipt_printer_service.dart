import 'dart:async';

import 'package:unified_esc_pos_printer/unified_esc_pos_printer.dart';

import '../core/utils/formatters.dart';
import '../models/cafe_receipt.dart';
import '../models/cart_item.dart';
import '../models/receipt.dart';
import '../models/saldo_receipt.dart';
import 'printer_filter.dart';
import 'printer_preference_storage.dart';
import 'ticket_layout.dart';

class ReceiptPrinterException implements Exception {
  final String message;

  const ReceiptPrinterException(this.message);

  @override
  String toString() => message;
}

class ReceiptPrinterService {
  Future<void> printReceipt(Receipt receipt) {
    return _print(buildTicket: () => _buildTicket(receipt));
  }

  Future<void> printCafeReceipt(CafeReceipt receipt) {
    return _print(buildTicket: () => _buildCafeTicket(receipt));
  }

  Future<void> printSaldoReceipt(SaldoReceipt receipt) {
    return _print(buildTicket: () => _buildSaldoTicket(receipt));
  }

  /// Kitchen order slip for a POS "keep" (parked order) save — [items] is
  /// just what's new in *this* save, not the whole held cart, so re-saving
  /// onto an existing hold only sends the kitchen the items it hasn't seen
  /// yet.
  Future<void> printKitchenOrder({
    required String keepCode,
    String? customerName,
    required List<CartItem> items,
  }) {
    return _print(
      buildTicket: () => _buildKitchenTicket(keepCode, customerName, items),
    );
  }

  /// Shared USB scan/connect/print/disconnect flow — [buildTicket] builds
  /// whichever ticket layout the caller needs.
  Future<void> _print({
    required Future<Ticket> Function() buildTicket,
  }) async {
    final manager = PrinterManager();

    try {
      await _run(manager, buildTicket).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw const ReceiptPrinterException(
          "Printer tidak merespon dalam 15 detik. Periksa kabel USB, "
          "pastikan printer menyala, lalu coba lagi.",
        ),
      );
    } on PrinterException catch (e) {
      throw ReceiptPrinterException(
        e.cause != null ? "${e.message} — ${e.cause}" : e.message,
      );
    } finally {
      // Fire-and-forget with its own timeout: if the hang that triggered
      // the timeout above is inside the plugin's native call, dispose()
      // would queue behind it and never return either — that must not
      // block this method from returning the error to the caller.
      unawaited(
        manager.dispose().timeout(const Duration(seconds: 3), onTimeout: () {}),
      );
    }
  }

  Future<void> _run(
    PrinterManager manager,
    Future<Ticket> Function() buildTicket,
  ) async {
    final printers = await manager.scanPrinters(
      types: {PrinterConnectionType.usb},
    );

    if (printers.isEmpty) {
      throw const ReceiptPrinterException(
        "Printer USB tidak ditemukan. Pastikan printer terhubung dan menyala.",
      );
    }

    final preferredId = await PrinterPreferenceStorage()
        .getSelectedPrinterIdentifier();
    await manager.connect(pickPrinter(printers, preferredId));
    await manager.printTicket(await buildTicket());
    await manager.disconnect();
  }

  Future<Ticket> _buildTicket(Receipt receipt) async {
    final ticket = await Ticket.create(PaperSize.mm80);

    TicketLayout.header(
      ticket,
      businessName: receipt.businessName,
      businessAddress: receipt.businessAddress,
      invoiceNumber: receipt.invoiceNumber,
      issuedAt: receipt.date,
      isReprint: receipt.isReprint,
    );

    TicketLayout.row(ticket, "Meja", receipt.tableLabel);
    TicketLayout.row(ticket, "Mulai", formatClock(receipt.startAt));
    TicketLayout.row(ticket, "Selesai", formatClock(receipt.endAt));
    TicketLayout.row(
      ticket,
      "Durasi",
      formatDurationWords(receipt.totalDuration),
    );

    if (receipt.periods.isNotEmpty) {
      TicketLayout.sectionTitle(ticket, "Rincian Waktu");
      for (final period in receipt.periods) {
        TicketLayout.row(ticket, period.label, formatCurrency(period.cost));
        TicketLayout.row(ticket, "  Durasi", formatDuration(period.duration));
      }
    }

    ticket.separator(char: '-', linesAfter: 1);
    TicketLayout.row(ticket, "Subtotal", formatCurrency(receipt.subtotal));
    if (receipt.promoName != null) {
      TicketLayout.row(ticket, "Promo", receipt.promoName!);
    }
    if (receipt.discountAmount > 0) {
      TicketLayout.row(
        ticket,
        "Diskon",
        "-${formatCurrency(receipt.discountAmount)}",
      );
    }

    TicketLayout.grandTotal(ticket, "GRAND TOTAL", receipt.grandTotal);

    TicketLayout.row(ticket, "Bayar", receipt.paymentMethod);
    TicketLayout.footer(ticket, receipt.cashierName);

    return ticket;
  }

  Future<Ticket> _buildCafeTicket(CafeReceipt receipt) async {
    final ticket = await Ticket.create(PaperSize.mm80);

    TicketLayout.header(
      ticket,
      businessName: receipt.businessName,
      businessAddress: receipt.businessAddress,
      invoiceNumber: receipt.invoiceNumber,
      issuedAt: receipt.date,
      isReprint: receipt.isReprint,
    );

    if (receipt.table != null) {
      TicketLayout.row(ticket, "Meja", receipt.table!);
    } else {
      final name = receipt.customerName?.trim();
      TicketLayout.row(
        ticket,
        "Customer",
        (name != null && name.isNotEmpty) ? name : "-",
      );
    }

    ticket.feed(1);
    for (final item in receipt.items) {
      ticket.text(item.name, style: const PrintTextStyle(bold: true));
      if (item.note != null) {
        ticket.text("  (${item.note})");
      }
      TicketLayout.row(
        ticket,
        "  ${item.quantity} x ${formatCurrency(item.price)}",
        formatCurrency(item.price * item.quantity),
      );
      for (final addon in item.addons) {
        TicketLayout.row(
          ticket,
          "  + ${addon.name} x${addon.quantity}",
          formatCurrency(addon.lineTotal),
        );
      }
    }

    ticket.separator(char: '-', linesAfter: 1);
    TicketLayout.row(ticket, "Subtotal", formatCurrency(receipt.subtotal));
    if (receipt.discountAmount > 0) {
      TicketLayout.row(
        ticket,
        "Diskon (${receipt.discountPercent}%)",
        "-${formatCurrency(receipt.discountAmount)}",
      );
    }
    if (receipt.tax > 0) {
      TicketLayout.row(ticket, "Pajak", formatCurrency(receipt.tax));
    }

    TicketLayout.grandTotal(ticket, "TOTAL", receipt.total);

    TicketLayout.row(ticket, "Bayar", receipt.paymentMethod);
    TicketLayout.footer(ticket, receipt.cashierName);

    return ticket;
  }

  Future<Ticket> _buildSaldoTicket(SaldoReceipt receipt) async {
    final ticket = await Ticket.create(PaperSize.mm80);

    TicketLayout.header(
      ticket,
      businessName: receipt.businessName,
      businessAddress: receipt.businessAddress,
      invoiceNumber: receipt.invoiceNumber,
      issuedAt: receipt.date,
    );

    TicketLayout.row(ticket, "Member", receipt.customerName);
    TicketLayout.row(ticket, "Nominal Saldo", formatCurrency(receipt.nominal));
    if (receipt.discount > 0) {
      TicketLayout.row(ticket, "Diskon", formatCurrency(receipt.discount));
    }

    TicketLayout.grandTotal(ticket, "TOTAL DIBAYAR", receipt.price);

    TicketLayout.row(ticket, "Bayar", receipt.paymentMethod);
    TicketLayout.footer(ticket, receipt.cashierName);

    return ticket;
  }

  Future<Ticket> _buildKitchenTicket(
    String keepCode,
    String? customerName,
    List<CartItem> items,
  ) async {
    final ticket = await Ticket.create(PaperSize.mm80);
    final now = DateTime.now();

    ticket.text(
      "PESANAN DAPUR",
      align: PrintAlign.center,
      style: const PrintTextStyle(bold: true),
    );
    ticket.separator(char: '=', linesAfter: 1);

    final name = customerName?.trim();
    TicketLayout.row(
      ticket,
      "Customer",
      (name != null && name.isNotEmpty) ? name : "-",
    );
    TicketLayout.row(ticket, "Kode", keepCode);
    ticket.text("${formatFullDate(now)}  ${formatClock(now)}");
    ticket.separator(char: '=', linesAfter: 1);

    for (final item in items) {
      ticket.text(
        "${item.quantity} x ${item.product.name}",
        style: const PrintTextStyle(bold: true),
      );
      final note = item.note?.trim();
      if (note != null && note.isNotEmpty) {
        ticket.text("  ($note)");
      }
      for (final addon in item.addons) {
        ticket.text("  + ${addon.quantity} x ${addon.product.name}");
      }
      ticket.feed(1);
    }

    ticket.separator(char: '=', linesAfter: 1);
    ticket.feed(3);
    ticket.cut();

    return ticket;
  }
}
