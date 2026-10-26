import '../constants.dart';

/// Helpers for fat values, which are used as map keys in a rate chart.
class Fat {
  Fat._();

  /// Normalizes a fat value to its map key: rounded to at most 2 decimals,
  /// always with at least 1 (`4` -> "4.0", `4.25` -> "4.25", `4.10` -> "4.1").
  static String key(double fat) {
    final rounded = (fat * 100).round() / 100;
    final text = rounded.toStringAsFixed(2);
    return text.endsWith('0') ? text.substring(0, text.length - 1) : text;
  }

  /// Parses a map key back to a number (null when it is not a number).
  static double? parse(String key) => double.tryParse(key);

  /// Keys of the default chart: 3.0, 3.1 ... 10.0.
  static List<String> seedKeys() {
    final steps = ((AppConstants.fatMax - AppConstants.fatMin) /
                AppConstants.fatStep)
            .round() +
        1;
    return List.generate(
      steps,
      (i) => key(AppConstants.fatMin + i * AppConstants.fatStep),
    );
  }

  /// True when [key] is not part of the default 3.0 .. 10.0 chart.
  static bool isCustom(String key) => !_seed.contains(key);

  static final Set<String> _seed = seedKeys().toSet();
}
