import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/messenger.dart';
import '../../../core/utils/fat.dart';
import '../../../core/widgets/state_views.dart';
import '../../accounts/models/account.dart';
import '../../profile/providers/profile_providers.dart';
import '../../rates/presentation/fat_dialog.dart';
import '../../rates/providers/rate_providers.dart';
import '../models/bill_slot.dart';
import '../providers/bill_providers.dart';
import 'week_range_dialog.dart';
import 'widgets/bill_header.dart';
import 'widgets/bill_pager.dart';
import 'widgets/bill_rows.dart';

/// Body of the account screens: header, day table, week navigation.
///
/// The same widget serves the admin (`readOnly: false`: inline editing,
/// Add week) and the supplier (`readOnly: true`: values only).
class BillView extends ConsumerWidget {
  const BillView({super.key, required this.account, required this.readOnly});

  final Account account;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bills = ref.watch(billsProvider(account.id));
    final session = ref.watch(sessionProvider);
    final notifier = ref.read(billsProvider(account.id).notifier);

    return bills.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(
        message: 'Could not load the bills.',
        onRetry: () => ref.invalidate(billsProvider(account.id)),
      ),
      data: (state) {
        final bill = state.current;

        if (bill == null) {
          return Column(children: [
            BillHeader(account: account, bill: null, showDairy: readOnly),
            Expanded(
              child: EmptyView(
                icon: Icons.event_note_outlined,
                message: readOnly ? 'No bills yet.' : 'No weeks yet.\nAdd the first week to start entering milk.',
                actionLabel: readOnly ? null : 'Add week',
                onAction: readOnly ? null : () => _addWeek(context, ref),
              ),
            ),
          ]);
        }

        final rateChart = ref.watch(ratesProvider).value?[account.category];
        double? rateFor(double fat) => rateChart?.rateFor(fat);

        return Column(
          children: [
            BillHeader(account: account, bill: bill, showDairy: readOnly),
            Expanded(
              child: RefreshIndicator(
                onRefresh: notifier.refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const BillTableHeader(),
                    for (final date in bill.dates)
                      readOnly
                          ? ReadOnlyBillRow(date: date, slot: bill.slot(date, session))
                          : EditableBillRow(
                              // New State per bill/day/session so inputs reset when switching.
                              key: ValueKey('${bill.id}-${date.toIso8601String()}-${session.key}'),
                              date: date,
                              slot: bill.slot(date, session),
                              rateFor: rateFor,
                              onChanged: (slot) => _onSlotChanged(context, ref, date, session, slot),
                            ),
                    BillTotalRow(
                      milk: bill.sessionMilk(session),
                      amount: bill.sessionAmount(session),
                    ),
                  ],
                ),
              ),
            ),
            BillPager(
              state: state,
              canAdd: !readOnly,
              onPrevious: notifier.showPrevious,
              onNext: notifier.showNext,
              onAdd: () => _addWeek(context, ref),
            ),
          ],
        );
      },
    );
  }

  /// Range picker, then create the bill. Overlaps are rejected with a message.
  Future<void> _addWeek(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(billsProvider(account.id).notifier);
    final cycle = ref.read(profileProvider).value?.billCycleDays ?? AppConstants.defaultBillCycleDays;
    final start = await showWeekRangeDialog(
      context,
      initialStart: notifier.suggestedStart(),
      cycleDays: cycle,
    );
    if (start == null) return;
    final error = await notifier.addBill(start);
    if (error != null) showAppSnack(error);
  }

  /// Saves the slot. A missing rate is only reported (never blocks): the entry
  /// keeps rate 0 and the admin may add the rate or ignore the message.
  void _onSlotChanged(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
    Session session,
    BillSlot slot,
  ) {
    ref.read(billsProvider(account.id).notifier).saveSlot(date, session, slot);

    if (slot.missingRate && slot.fat > 0) {
      final fatKey = Fat.key(slot.fat);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('No rate for fat $fatKey'),
          action: SnackBarAction(
            label: 'Add rate',
            onPressed: () => _addMissingRate(context, ref, date, session, slot),
          ),
        ));
    }
  }

  /// "Add rate" action: saves the rate in the chart and applies it to this entry.
  Future<void> _addMissingRate(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
    Session session,
    BillSlot slot,
  ) async {
    final result = await showFatDialog(context, title: 'Add rate', fat: slot.fat, fatLocked: true);
    if (result == null) return;
    ref.read(ratesProvider.notifier).setFat(account.category, result.fat, result.rate);
    ref.read(billsProvider(account.id).notifier).saveSlot(
          date,
          session,
          BillSlot(milk: slot.milk, fat: slot.fat, rate: result.rate),
        );
  }
}
