import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../accounts/models/account.dart';
import '../../models/bill.dart';

/// Account name and the bill's date range and totals (both sessions), shown
/// directly on the screen: no card, no shadow.
class BillHeader extends StatelessWidget {
  const BillHeader({
    super.key,
    required this.account,
    required this.bill,
    this.showDairy = false,
    this.menu,
  });

  final Account account;
  final Bill? bill;

  /// Suppliers also see which dairy the account belongs to.
  final bool showDairy;

  /// Optional dropdown next to the name (QR code, delete week) for the admin.
  final Widget? menu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = showDairy && account.dairyName.isNotEmpty
        ? '${account.dairyName} · ${account.category}'
        : account.category;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
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
              ?menu,
            ],
          ),
          if (bill != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Week: ${Fmt.fullDate(bill!.startDate)} to ${Fmt.fullDate(bill!.endDate)}',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 4),
                  Text('Total Milk: ${Fmt.num(bill!.totalMilk)} ltr', style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 4),
                  Text('Total Bill: ${Fmt.money(bill!.totalAmount)} RS', style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
