import '../../../core/firestore/firestore_paths.dart';
import '../../../core/utils/fat.dart';

/// Rate chart of one milk category (for example COW): fat -> rate per litre.
///
/// A rate of 0 means "not set yet". Fat keys are normalized with [Fat.key].
class RateChart {
  const RateChart({required this.category, required this.fats});

  final String category;
  final Map<String, double> fats;

  /// New chart with fat 3.0 .. 10.0 at rate 0.
  factory RateChart.seeded(String category) => RateChart(
    category: category,
    fats: {for (final k in Fat.seedKeys()) k: 0.0},
  );

  factory RateChart.fromMap(String category, Json m) {
    final raw = (m['fats'] as Map?) ?? const {};
    return RateChart(
      category: category,
      fats: {
        for (final e in raw.entries)
          e.key as String: (e.value as num).toDouble(),
      },
    );
  }

  /// Rate for [fat], or null when the chart has no usable rate for it
  /// (fat missing from the chart, or still 0). Callers treat null as 0.
  double? rateFor(double fat) {
    final rate = fats[Fat.key(fat)];
    return (rate == null || rate <= 0) ? null : rate;
  }

  /// Entries sorted by fat ascending.
  List<MapEntry<String, double>> get sorted {
    final list = fats.entries.toList();
    list.sort(
      (a, b) => (Fat.parse(a.key) ?? 0).compareTo(Fat.parse(b.key) ?? 0),
    );
    return list;
  }

  RateChart withFat(String key, double rate) =>
      RateChart(category: category, fats: {...fats, key: rate});

  RateChart withoutFat(String key) =>
      RateChart(category: category, fats: {...fats}..remove(key));
}
