import 'package:intl/intl.dart';

final _currencyFormat = NumberFormat.decimalPattern('id_ID');
final _timeFormat = DateFormat('HH:mm');
final _clockFormat = DateFormat('HH:mm:ss');
final _dateFormat = DateFormat('dd/MM/yyyy');
final _apiDateTimeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
final _apiDateFormat = DateFormat('yyyy-MM-dd');

const _indonesianMonths = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

String formatCurrency(int amount) => "Rp ${_currencyFormat.format(amount)}";

String formatThousands(int amount) => _currencyFormat.format(amount);

/// Parses a number typed through [ThousandsInputFormatter] (or any string
/// with non-digit separators) back into an int. Returns null when there are
/// no digits at all.
int? parseThousands(String text) {
  final digitsOnly = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitsOnly.isEmpty) return null;
  return int.tryParse(digitsOnly);
}

String formatTime(DateTime time) => _timeFormat.format(time);

String formatDate(DateTime date) => _dateFormat.format(date);

/// Formats a DateTime the way the billing API expects it in request bodies,
/// e.g. table_start_time / table_end_time ("yyyy-MM-dd HH:mm:ss").
String formatApiDateTime(DateTime date) => _apiDateTimeFormat.format(date);

/// Formats a date-only value the way report filters expect it in request
/// bodies, e.g. date_from / date_to ("yyyy-MM-dd").
String formatApiDate(DateTime date) => _apiDateFormat.format(date);

String formatClock(DateTime time) => _clockFormat.format(time);

String formatFullDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  return "$day ${_indonesianMonths[date.month - 1]} ${date.year}";
}

String formatDuration(Duration duration) {
  final clamped = duration.isNegative ? Duration.zero : duration;
  String two(int n) => n.toString().padLeft(2, '0');
  return "${two(clamped.inHours)}:${two(clamped.inMinutes % 60)}:${two(clamped.inSeconds % 60)}";
}

String formatDurationWords(Duration duration) {
  final clamped = duration.isNegative ? Duration.zero : duration;
  return "${clamped.inHours} jam ${clamped.inMinutes % 60} menit ${clamped.inSeconds % 60} detik";
}

/// Parses a duration the way the billing API returns it in responses, e.g.
/// time_remaining ("HH:mm:ss"). Returns null for anything that doesn't
/// match.
Duration? parseApiDuration(String? value) {
  if (value == null || value.trim().isEmpty) return null;

  final parts = value.trim().split(':');
  if (parts.length != 3) return null;

  final hours = int.tryParse(parts[0]);
  final minutes = int.tryParse(parts[1]);
  final seconds = int.tryParse(parts[2]);
  if (hours == null || minutes == null || seconds == null) return null;

  return Duration(hours: hours, minutes: minutes, seconds: seconds);
}
