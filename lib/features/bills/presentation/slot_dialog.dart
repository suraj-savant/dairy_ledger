import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';
import '../../../core/utils/formatters.dart';
import '../models/bill_slot.dart';
import '../models/slot_resolver.dart';

/// Dialog to edit one milking slot (milk, fat, rate), opened by tapping a
/// row, the same way the Rates screen edits a rate. Returns the new slot, or
/// null when cancelled.
///
/// Typing a fat fills the rate from the rate chart. Typing a rate yourself
/// overrides the chart. Nothing is mandatory: a missing rate saves as 0.
Future<BillSlot?> showSlotDialog(
  BuildContext context, {
  required DateTime date,
  required String sessionLabel,
  required BillSlot slot,
  required double? Function(double fat) rateFor,
}) {
  return showDialog<BillSlot>(
    context: context,
    builder: (_) => _SlotDialog(date: date, sessionLabel: sessionLabel, slot: slot, rateFor: rateFor),
  );
}

class _SlotDialog extends StatefulWidget {
  const _SlotDialog({
    required this.date,
    required this.sessionLabel,
    required this.slot,
    required this.rateFor,
  });

  final DateTime date;
  final String sessionLabel;
  final BillSlot slot;
  final double? Function(double fat) rateFor;

  @override
  State<_SlotDialog> createState() => _SlotDialogState();
}

class _SlotDialogState extends State<_SlotDialog> {
  static String _text(double v) => v == 0 ? '' : Fmt.num(v);
  static final _decimal = [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))];

  late final _milk = TextEditingController(text: _text(widget.slot.milk));
  late final _fat = TextEditingController(text: _text(widget.slot.fat));
  late final _rate = TextEditingController(text: _text(widget.slot.rate));
  late bool _rateManual = widget.slot.rateManual;

  @override
  void dispose() {
    _milk.dispose();
    _fat.dispose();
    _rate.dispose();
    super.dispose();
  }

  double get _milkValue => Fmt.parseNum(_milk.text) ?? 0;
  double get _fatValue => Fmt.parseNum(_fat.text) ?? 0;

  /// The slot these inputs would save right now.
  BillSlot get _resolved => resolveSlot(
        milk: _milkValue,
        fat: _fatValue,
        rateText: _rate.text,
        rateManual: _rateManual,
        rateFor: widget.rateFor,
      );

  void _onFatChanged(String _) {
    if (!_rateManual) _rate.text = _text(_resolved.rate); // show the chart rate
    setState(() {});
  }

  void _onRateChanged(String text) {
    _rateManual = text.trim().isNotEmpty;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolved = _resolved;
    final noRate = (_milkValue > 0 || _fatValue > 0) && resolved.rate == 0;

    Widget field(String label, TextEditingController c, {
      ValueChanged<String>? onChanged,
      TextInputAction action = TextInputAction.next,
      bool autofocus = false,
    }) =>
        TextField(
          controller: c,
          autofocus: autofocus,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: action,
          inputFormatters: _decimal,
          decoration: InputDecoration(labelText: label, hintText: '0'),
          onChanged: onChanged ?? (_) => setState(() {}),
          onSubmitted: action == TextInputAction.done ? (_) => Navigator.pop(context, _resolved) : null,
        );

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(Fmt.fullDate(widget.date)),
          Text(widget.sessionLabel, style: theme.textTheme.bodyMedium),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            field('Milk (litres)', _milk, autofocus: true),
            const SizedBox(height: 16),
            field('Fat', _fat, onChanged: _onFatChanged),
            const SizedBox(height: 16),
            field('Rate per litre', _rate, onChanged: _onRateChanged, action: TextInputAction.done),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Total', style: theme.textTheme.titleMedium),
                const Spacer(),
                Text('₹ ${Fmt.money(resolved.total)}',
                    style: theme.textTheme.titleLarge?.copyWith(color: AppTheme.deepPurple)),
              ],
            ),
            if (noRate) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.amberContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'No rate for this fat. It will be saved with rate 0. '
                  'Type a rate above, or add this fat in the Rates tab.',
                  style: TextStyle(fontSize: 16, color: Color(0xFF2A1800)),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, _resolved), child: const Text('Save')),
      ],
    );
  }
}
