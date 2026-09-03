import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Which transport the saved printer uses.
enum PrinterKind { usb, network }

/// The operator's saved printer pick — see [ReceiptPrinterService] and
/// [CashierSummaryPrinterService].
///
/// - USB: [identifier] is the OS identifier (serial port path like `COM3` /
///   `/dev/ttyUSB0`, or `vendorId:productId` on Android). Matched against a
///   fresh scan result.
/// - Network (LAN): [identifier] is `host:port` (e.g. `192.168.1.50:9100`).
///   Not matched against a scan — a static-IP printer should print even when
///   subnet discovery finds nothing — the device is rebuilt from here.
class PrinterSelection {
  final PrinterKind kind;
  final String identifier;
  final String? label;

  const PrinterSelection({
    required this.kind,
    required this.identifier,
    this.label,
  });

  bool get isNetwork => kind == PrinterKind.network;

  String get host => isNetwork ? identifier.split(':').first : identifier;

  int get port {
    if (!isNetwork) return 9100;
    final parts = identifier.split(':');
    return parts.length > 1 ? int.tryParse(parts[1]) ?? 9100 : 9100;
  }

  String get displayName => label?.trim().isNotEmpty == true ? label! : identifier;

  Map<String, dynamic> toJson() => {
        "kind": kind.name,
        "identifier": identifier,
        if (label != null) "label": label,
      };

  static PrinterSelection? fromStored(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final kind = decoded["kind"] == PrinterKind.network.name
            ? PrinterKind.network
            : PrinterKind.usb;
        final id = decoded["identifier"]?.toString() ?? "";
        if (id.isEmpty) return null;
        return PrinterSelection(
          kind: kind,
          identifier: id,
          label: decoded["label"]?.toString(),
        );
      }
    } catch (_) {
      // Not JSON — legacy value: a bare USB identifier string.
    }
    return PrinterSelection(kind: PrinterKind.usb, identifier: raw);
  }
}

/// Persists which printer (USB or LAN) the operator picked to print
/// receipts with. Without this, printing has to guess by picking the first
/// scan result, which can land on the wrong entry when the OS lists several
/// printers (virtual printers, or more than one driver for one device).
class PrinterPreferenceStorage {
  static const _key = "selected_printer_identifier";

  Future<PrinterSelection?> getSelection() async {
    final prefs = await SharedPreferences.getInstance();
    return PrinterSelection.fromStored(prefs.getString(_key));
  }

  Future<void> setSelection(PrinterSelection? selection) async {
    final prefs = await SharedPreferences.getInstance();
    if (selection == null || selection.identifier.isEmpty) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, jsonEncode(selection.toJson()));
    }
  }
}
