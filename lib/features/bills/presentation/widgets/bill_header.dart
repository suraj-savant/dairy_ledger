import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../accounts/models/account.dart';
import '../../models/bill.dart';

/// Account name, the bill's date range and its totals (both sessions).
class BillHeader extends StatelessWidget {
  const BillHeader({super.key, required this.account, required this.bill, this.showDairy = false});

  final Account account;
  final Bill? bill;

  /// Suppliers also see which dairy the account belongs to.
  final bool showDairy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = showDairy && account.dairyName.isNotEmpty
        ? '${account.dairyName} · ${account.category}'
        : account.category;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.deepPurpleContainer,
                  child: Text(account.initial,
                      style: const TextStyle(
                          color: AppTheme.deepPurple, fontWeight: FontWeight.bold, fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(account.name, style: theme.textTheme.titleLarge),
                      Text(subtitle, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            if (bill != null) ...[
              const SizedBox(height: 12),
              Text(
                'Week: ${Fmt.range(bill!.startDate, bill!.endDate)}',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _Stat(label: 'Total Milk', value: '${Fmt.num(bill!.totalMilk)} ltr')),
                  Expanded(child: _Stat(label: 'Total Bill', value: '₹ ${Fmt.money(bill!.totalAmount)}')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary)),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: theme.textTheme.titleLarge?.copyWith(color: AppTheme.deepPurple)),
        ),
      ],
    );
  }
}
