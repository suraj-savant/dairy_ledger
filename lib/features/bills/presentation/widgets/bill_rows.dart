import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../models/bill_slot.dart';

/// Relative widths of the five table columns, shared by every row.
class BillColumns {
  BillColumns._();
  static const date = 3;
  static const milk = 3;
  static const fat = 2;
  static const rate = 3;
  static const total = 3;
}

bool _isToday(DateTime d) {
  final n = DateTime.now();
  return d.year == n.year && d.month == n.month && d.day == n.day;
}

/// `DATE | MILK | FAT | RATE | TOTAL` column titles.
class BillTableHeader extends StatelessWidget {
  const BillTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge;
    Widget cell(String text, int flex, {TextAlign align = TextAlign.center}) => Expanded(
          flex: flex,
          child: FittedBox(fit: BoxFit.scaleDown, child: Text(text, style: style, textAlign: align)),
        );
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(children: [
        cell('DATE', BillColumns.date, align: TextAlign.start),
        cell('MILK', BillColumns.milk),
        cell('FAT', BillColumns.fat),
        cell('RATE', BillColumns.rate),
        cell('TOTAL', BillColumns.total, align: TextAlign.end),
      ]),
    );
  }
}

/// Footer: totals of the session on screen.
class BillTotalRow extends StatelessWidget {
  const BillTotalRow({super.key, required this.milk, required this.amount});
  final double milk;
  final double amount;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(color: AppTheme.deepPurple, fontWeight: FontWeight.bold);
    Widget cell(String text, int flex, {TextAlign align = TextAlign.center}) => Expanded(
          flex: flex,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: align == TextAlign.end ? Alignment.centerRight : Alignment.center,
            child: Text(text, style: style),
          ),
        );
    return Container(
      color: AppTheme.deepPurpleContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Row(children: [
        Expanded(flex: BillColumns.date, child: Text('TOTAL', style: style)),
        cell(Fmt.num(milk), BillColumns.milk),
        const Spacer(flex: BillColumns.fat),
        const Spacer(flex: BillColumns.rate),
        cell(Fmt.money(amount), BillColumns.total, align: TextAlign.end),
      ]),
    );
  }
}

/// Read-only row (supplier screens).
class ReadOnlyBillRow extends StatelessWidget {
  const ReadOnlyBillRow({super.key, required this.date, required this.slot});
  final DateTime date;
  final BillSlot slot;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge;
    String show(double v) => v == 0 ? '–' : Fmt.num(v);
    Widget cell(String text, int flex, {TextAlign align = TextAlign.center, Color? bg}) => Expanded(
          flex: flex,
          child: Container(
            alignment: align == TextAlign.end
                ? Alignment.centerRight
                : (align == TextAlign.start ? Alignment.centerLeft : Alignment.center),
            color: bg,
            height: 56,
            child: FittedBox(fit: BoxFit.scaleDown, child: Text(text, style: style)),
          ),
        );
    return Container(
      color: _isToday(date) ? AppTheme.amberContainer : null,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        cell(Fmt.shortDate(date), BillColumns.date, align: TextAlign.start),
        cell(show(slot.milk), BillColumns.milk),
        cell(show(slot.fat), BillColumns.fat),
        cell(show(slot.rate), BillColumns.rate, bg: slot.missingRate ? AppTheme.amberContainer : null),
        cell(slot.total == 0 ? '–' : Fmt.money(slot.total), BillColumns.total, align: TextAlign.end),
      ]),
    );
  }
}

/// Editable row (admin). Milk, fat and rate are inline inputs; the date is fixed.
///
/// Behaviour:
///  * Typing a fat fills the rate from the rate chart ([rateFor]).
///  * Typing a rate overrides the chart; that is remembered as `rateManual`
///    and kept when the fat changes later. Clearing the rate goes back to the chart.
///  * Nothing is mandatory; empty means 0. A missing rate stays 0 and the
///    cell is highlighted.
///  * The row is saved once, when focus leaves the whole row.
class EditableBillRow extends StatefulWidget {
  const EditableBillRow({
    super.key,
    required this.date,
    required this.slot,
    required this.rateFor,
    required this.onChanged,
  });

  final DateTime date;
  final BillSlot slot;

  /// Rate for a fat from the category chart, or null when there is none.
  final double? Function(double fat) rateFor;

  /// Called with the new slot when the row loses focus and something changed.
  final ValueChanged<BillSlot> onChanged;

  @override
  State<EditableBillRow> createState() => _EditableBillRowState();
}

class _EditableBillRowState extends State<EditableBillRow> {
  static String _text(double v) => v == 0 ? '' : Fmt.num(v);

  late final _milk = TextEditingController(text: _text(widget.slot.milk));
  late final _fat = TextEditingController(text: _text(widget.slot.fat));
  late final _rate = TextEditingController(text: _text(widget.slot.rate));
  late bool _rateManual = widget.slot.rateManual;
  bool _focused = false;

  static final _decimal = [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))];

  /// The slot changed from outside (for example "Add rate" applied a rate):
  /// show it, unless the admin is typing in this row.
  @override
  void didUpdateWidget(EditableBillRow old) {
    super.didUpdateWidget(old);
    if (old.slot != widget.slot && !_focused) {
      _milk.text = _text(widget.slot.milk);
      _fat.text = _text(widget.slot.fat);
      _rate.text = _text(widget.slot.rate);
      _rateManual = widget.slot.rateManual;
    }
  }

  @override
  void dispose() {
    _milk.dispose();
    _fat.dispose();
    _rate.dispose();
    super.dispose();
  }

  double get _milkValue => Fmt.parseNum(_milk.text) ?? 0;
  double get _fatValue => Fmt.parseNum(_fat.text) ?? 0;

  /// Rate that applies right now: the typed override, else the chart.
  double get _effectiveRate {
    final typed = Fmt.parseNum(_rate.text);
    if (_rateManual && typed != null) return typed;
    return _fatValue > 0 ? (widget.rateFor(_fatValue) ?? 0) : 0;
  }

  void _onFatChanged(String _) {
    if (!_rateManual) _rate.text = _text(_effectiveRate); // live preview of the chart rate
    setState(() {});
  }

  void _onRateChanged(String text) {
    _rateManual = text.trim().isNotEmpty;
    setState(() {});
  }

  /// Focus left the row: build the slot and hand it up if it changed.
  void _commit() {
    if (!mounted) return;
    final auto = _fatValue > 0 ? widget.rateFor(_fatValue) : null;
    final typed = Fmt.parseNum(_rate.text);

    double rate;
    bool manual;
    if (_rateManual && typed != null && typed != (auto ?? 0)) {
      rate = typed;
      manual = true;
    } else {
      rate = auto ?? 0;
      manual = false;
    }
    _rateManual = manual;
    _rate.text = _text(rate);
    setState(() {});

    final slot = BillSlot(milk: _milkValue, fat: _fatValue, rate: rate, rateManual: manual);
    if (slot != widget.slot) widget.onChanged(slot);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = Fmt.round2(_milkValue * _effectiveRate);
    final missingRate = _milkValue > 0 && _effectiveRate == 0;

    Widget field(TextEditingController c, int flex, {
      TextInputAction action = TextInputAction.next,
      ValueChanged<String>? onChanged,
      Color? fill,
    }) =>
        Expanded(
          flex: flex,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: TextField(
              controller: c,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: action,
              inputFormatters: _decimal,
              textAlign: TextAlign.center,
              onChanged: onChanged ?? (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: fill,
                hintText: '0',
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 17),
              ),
            ),
          ),
        );

    return Focus(
      // Reports focus anywhere inside the row: save when it leaves the row.
      skipTraversal: true,
      canRequestFocus: false,
      onFocusChange: (hasFocus) {
        _focused = hasFocus;
        if (!hasFocus) _commit();
      },
      child: Container(
        color: _isToday(widget.date) ? AppTheme.amberContainer : null,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Row(children: [
          Expanded(
            flex: BillColumns.date,
            child: Padding(
              padding: const EdgeInsets.only(left: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(Fmt.shortDate(widget.date), style: theme.textTheme.bodyLarge),
              ),
            ),
          ),
          field(_milk, BillColumns.milk),
          field(_fat, BillColumns.fat, onChanged: _onFatChanged),
          field(
            _rate,
            BillColumns.rate,
            action: TextInputAction.done,
            onChanged: _onRateChanged,
            fill: missingRate ? AppTheme.amberContainer : null,
          ),
          Expanded(
            flex: BillColumns.total,
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(total == 0 ? '–' : Fmt.money(total), style: theme.textTheme.bodyLarge),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
