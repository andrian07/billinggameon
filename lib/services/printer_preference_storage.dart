import 'package:shared_preferences/shared_preferences.dart';

/// Persists which USB printer (by its Windows/OS identifier) the operator
/// picked to print receipts with — see [ReceiptPrinterService] and
/// [CashierSummaryPrinterService]. Without this, printing has to guess by
/// picking the first scan result, which can land on the wrong entry when
/// Windows lists several printers (virtual printers, or more than one real
/// printer set up for the same physical device with different drivers).
class PrinterPreferenceStorage {
  static const _key = "selected_printer_identifier";

  Future<String?> getSelectedPrinterIdentifier() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  Future<void> setSelectedPrinterIdentifier(String? identifier) async {
    final prefs = await SharedPreferences.getInstance();
    if (identifier == null || identifier.isEmpty) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, identifier);
    }
  }
}
