import 'bill_slot.dart';

/// Turns what the admin typed into a [BillSlot].
///
/// * The rate comes from the rate chart ([rateFor]) for the typed fat.
/// * A typed rate that differs from the chart is a manual override
///   (`rateManual`) and is kept when the fat changes later.
/// * An empty rate field, or one equal to the chart, goes back to the chart.
/// * A fat without a chart rate gives rate 0. That never blocks saving.
BillSlot resolveSlot({
  required double milk,
  required double fat,
  required String rateText,
  required bool rateManual,
  required double? Function(double fat) rateFor,
}) {
  final auto = fat > 0 ? rateFor(fat) : null;
  final typed = double.tryParse(rateText.trim());

  if (rateManual && typed != null && typed != (auto ?? 0)) {
    return BillSlot(milk: milk, fat: fat, rate: typed, rateManual: true);
  }
  return BillSlot(milk: milk, fat: fat, rate: auto ?? 0);
}
