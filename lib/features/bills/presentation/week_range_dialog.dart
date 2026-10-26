import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';

/// Range-based date selection for a new week (bill).
///
/// The admin only picks the first day. The length is fixed by the billing
/// cycle, so the end date is shown but cannot be changed and no day outside
/// the range can exist. Returns the chosen start date, or null if cancelled.
Future<DateTime?> showWeekRangeDialog(
  BuildContext context, {
  required DateTime initialStart,
  required int cycleDays,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) => _WeekRangeDialog(initialStart: initialStart, cycleDays: cycleDays),
  );
}

class _WeekRangeDialog extends StatefulWidget {
  const _WeekRangeDialog({required this.initialStart, required this.cycleDays});
  final DateTime initialStart;
  final int cycleDays;

  @override
  State<_WeekRangeDialog> createState() => _WeekRangeDialogState();
}

class _WeekRangeDialogState extends State<_WeekRangeDialog> {
  late DateTime _start = widget.initialStart;

  DateTime get _end =>
      DateTime(_start.year, _start.month, _start.day + widget.cycleDays - 1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    return AlertDialog(
      title: const Text('New week'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pick the first day. The week covers ${widget.cycleDays} '
                '${widget.cycleDays == 1 ? 'day' : 'days'}.',
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  Fmt.range(_start, _end),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
              CalendarDatePicker(
                initialDate: _start,
                firstDate: DateTime(2020),
                lastDate: DateTime(now.year + 1, 12, 31),
                onDateChanged: (d) => setState(() => _start = DateTime(d.year, d.month, d.day)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, _start), child: const Text('Create')),
      ],
    );
  }
}
