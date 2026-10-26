import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../models/bill_slot.dart';

/// Relative widths of the five table columns, shared by every row.
class BillColumns {
  BillColumns._();
  static const date = 4;
  static const milk = 2;
  static const fat = 2;
  static const rate = 2;
  static const total = 3;
}

const _rowPadding = EdgeInsets.symmetric(horizontal: 16);

/// One cell: text that shrinks instead of overflowing at large font sizes.
Widget _cell(String text, int flex, TextStyle? style, {Alignment alignment = Alignment.center}) =>
    Expanded(
      flex: flex,
      child: Align(
        alignment: alignment,
        child: FittedBox(fit: BoxFit.scaleDown, child: Text(text, style: style)),
      ),
    );

/// `DATE | MILK | FAT | RATE | TOTAL` column titles.
class BillTableHeader extends StatelessWidget {
  const BillTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge;
    return Padding(
      padding: _rowPadding.add(const EdgeInsets.symmetric(vertical: 12)),
      child: Row(children: [
        _cell('DATE', BillColumns.date, style, alignment: Alignment.centerLeft),
        _cell('MILK', BillColumns.milk, style),
        _cell('FAT', BillColumns.fat, style),
        _cell('RATE', BillColumns.rate, style),
        _cell('TOTAL', BillColumns.total, style, alignment: Alignment.centerRight),
      ]),
    );
  }
}

/// One day of one session, styled like the rows of the Rates screen: plain,
/// at least 56dp high, zeros when nothing is entered. The admin taps it to
/// edit in a dialog; [onTap] is null on the supplier's read-only screen.
class BillDayRow extends StatelessWidget {
  const BillDayRow({super.key, required this.date, required this.slot, this.onTap});

  final DateTime date;
  final BillSlot slot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: _rowPadding.add(const EdgeInsets.symmetric(vertical: 8)),
        child: Row(children: [
          _cell(Fmt.fullDate(date), BillColumns.date, style, alignment: Alignment.centerLeft),
          _cell(Fmt.num(slot.milk), BillColumns.milk, style),
          _cell(Fmt.num(slot.fat), BillColumns.fat, style),
          _cell(Fmt.num(slot.rate), BillColumns.rate, style),
          _cell(Fmt.money(slot.total), BillColumns.total, style, alignment: Alignment.centerRight),
        ]),
      ),
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
    final style = Theme.of(context).textTheme.titleMedium;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outline)),
      ),
      padding: _rowPadding.add(const EdgeInsets.symmetric(vertical: 16)),
      child: Row(children: [
        _cell('TOTAL', BillColumns.date, style, alignment: Alignment.centerLeft),
        _cell(Fmt.num(milk), BillColumns.milk, style),
        const Spacer(flex: BillColumns.fat + BillColumns.rate),
        _cell(Fmt.money(amount), BillColumns.total, style, alignment: Alignment.centerRight),
      ]),
    );
  }
}
