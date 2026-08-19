import 'package:flutter/services.dart';

import 'formatters.dart';

/// Live-formats a numeric text field with thousands separators as the user
/// types, e.g. typing "50000" shows "50.000".
class ThousandsInputFormatter extends TextInputFormatter {
  const ThousandsInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final value = parseThousands(newValue.text);
    if (value == null) {
      return const TextEditingValue();
    }

    final formatted = formatThousands(value);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
