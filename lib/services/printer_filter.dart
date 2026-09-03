import 'package:unified_esc_pos_printer/unified_esc_pos_printer.dart';

import 'printer_preference_storage.dart';

/// On Windows, USB printer "scanning" goes through the Print Spooler and
/// lists every installed printer — including virtual ones like "Send to
/// OneNote", "Microsoft Print to PDF", or "Fax" — not just the physical
/// thermal printer. Picking the first scan result can silently route
/// receipts to one of these instead. This filters known virtual printers
/// out so the real printer is preferred; if nothing survives the filter
/// (e.g. only virtual printers are installed), the original list is
/// returned so callers still get a usable error instead of an empty one.
const _virtualPrinterKeywords = [
  'onenote',
  'pdf',
  'fax',
  'xps document writer',
];

List<PrinterDevice> excludeVirtualPrinters(List<PrinterDevice> printers) {
  final real = printers.where((printer) {
    final name = printer.name.toLowerCase();
    return !_virtualPrinterKeywords.any(name.contains);
  }).toList();
  return real.isEmpty ? printers : real;
}

/// Rebuilds the [PrinterDevice] for a saved [PrinterSelection].
///
/// - Network: always synthesizes a [NetworkPrinterDevice] from the stored
///   `host:port` — a static-IP printer must print even when subnet discovery
///   returned nothing (wired LAN, `getWifiIP()` null, firewalled probe port).
/// - USB: matches the stored identifier against [scanned]; returns null if
///   the printer is no longer present (renamed/unplugged since it was picked).
PrinterDevice? resolveSelection(
  List<PrinterDevice> scanned,
  PrinterSelection? selection,
) {
  if (selection == null) return null;
  if (selection.isNetwork) {
    return NetworkPrinterDevice(
      name: selection.displayName,
      host: selection.host,
      port: selection.port,
    );
  }
  for (final printer in scanned) {
    if (printer is UsbPrinterDevice &&
        printer.identifier == selection.identifier) {
      return printer;
    }
  }
  return null;
}

/// Picks which printer to connect to out of a raw (unfiltered) scan result.
///
/// Prefers the operator's saved choice ([resolveSelection]) — a deliberate
/// pick that wins even over the virtual-printer filter. Falls back to the
/// first non-virtual printer when there's no saved choice, or the saved USB
/// one is no longer present.
PrinterDevice pickPrinter(
  List<PrinterDevice> printers,
  PrinterSelection? selection,
) {
  return resolveSelection(printers, selection) ??
      excludeVirtualPrinters(printers).first;
}
