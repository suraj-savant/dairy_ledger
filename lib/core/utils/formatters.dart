import 'package:intl/intl.dart';

/// Date and number helpers shared by the data and UI layers.
class Fmt {
  Fmt._();

  static final DateFormat _key = DateFormat('yyyy-MM-dd');
  static final DateFormat _short = DateFormat('dd MMM');
  static final DateFormat _long = DateFormat('dd MMM yyyy');
  static final DateFormat _full = DateFormat('dd-MM-yyyy');

  /// Firestore date key, e.g. `2026-10-12`. Sorts chronologically as text.
  static String dateKey(DateTime d) => _key.format(d);

  /// Inverse of [dateKey] (local midnight).
  static DateTime parseKey(String key) => _key.parse(key);

  /// `12 Oct`, used in table rows.
  static String shortDate(DateTime d) => _short.format(d);

  /// `12 Oct 2026`.
  static String longDate(DateTime d) => _long.format(d);

  /// `12-10-2026`, the numeric format used in the bill screens.
  static String fullDate(DateTime d) => _full.format(d);

  /// `12 Oct 2026 – 18 Oct 2026`.
  static String range(DateTime start, DateTime end) =>
      '${longDate(start)} – ${longDate(end)}';

  /// Rounds to 2 decimals (money and litres).
  static double round2(double v) => (v * 100).round() / 100;

  /// Number without trailing zeros: `5` , `5.5`, `5.25`. Zero is shown as `0`.
  static String num(double v) {
    final r = round2(v);
    if (r == r.roundToDouble()) return r.toInt().toString();
    final s = r.toStringAsFixed(2);
    return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
  }

  /// Currency amount with two decimals, e.g. `286.00`.
  static String money(double v) => round2(v).toStringAsFixed(2);

  /// Parses user input; empty or invalid text gives null.
  static double? parseNum(String text) => double.tryParse(text.trim());
}
