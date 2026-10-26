import '../../../core/firestore/firestore_paths.dart';
import '../../../core/utils/formatters.dart';

/// One milking session of one day: milk (litres), fat, rate per litre.
///
/// [rate] is stored on the slot, so later changes to the rate chart never
/// alter old bills. [rateManual] marks a rate typed by the admin; it is kept
/// when the fat is edited later (clearing the rate removes the override).
class BillSlot {
  const BillSlot({
    this.milk = 0,
    this.fat = 0,
    this.rate = 0,
    this.rateManual = false,
  });

  final double milk;
  final double fat;
  final double rate;
  final bool rateManual;

  static const BillSlot empty = BillSlot();

  /// Amount for this slot, rounded to 2 decimals.
  double get total => Fmt.round2(milk * rate);

  /// Nothing entered: such slots are not stored.
  bool get isEmpty => milk == 0 && fat == 0 && rate == 0;

  /// Milk was entered but no rate is available (shown highlighted in amber).
  bool get missingRate => milk > 0 && rate == 0;

  factory BillSlot.fromMap(Json m) => BillSlot(
        milk: (m['milk'] as num?)?.toDouble() ?? 0,
        fat: (m['fat'] as num?)?.toDouble() ?? 0,
        rate: (m['rate'] as num?)?.toDouble() ?? 0,
        rateManual: m['rateManual'] == true,
      );

  Json toMap() => {
        'milk': milk,
        'fat': fat,
        'rate': rate,
        if (rateManual) 'rateManual': true,
      };

  @override
  bool operator ==(Object other) =>
      other is BillSlot &&
      other.milk == milk &&
      other.fat == fat &&
      other.rate == rate &&
      other.rateManual == rateManual;

  @override
  int get hashCode => Object.hash(milk, fat, rate, rateManual);

  @override
  String toString() => 'BillSlot(milk=$milk fat=$fat rate=$rate manual=$rateManual)';
}
