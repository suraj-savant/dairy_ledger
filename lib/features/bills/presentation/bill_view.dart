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
import '../models/bill.dart';
import '../models/bill_slot.dart';
import '../providers/bill_providers.dart';
import 'slot_dialog.dart';
import 'week_range_dialog.dart';
import 'widgets/bill_header.dart';
import 'widgets/bill_pager.dart';
import 'widgets/bill_rows.dart';

/// Body of the account screens: account details, Morning / Evening tabs with
/// their day tables, and the week navigation buttons.
///
/// The same widget serves the admin (`readOnly: false`: rows open an edit
/// dialog, Add week) and the supplier (`readOnly: true`: values only).
class BillView extends ConsumerWidget {
  const BillView({super.key, required this.account, required this.readOnly, this.headerMenu});

  final Account account;
  final bool readOnly;

  /// Admin dropdown next to the account name (QR code, delete week).
  final Widget? headerMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bills = ref.watch(billsProvider(account.ref));
    final notifier = ref.read(billsProvider(account.ref).notifier);
    // Suppliers see which dairy this is; the admin already knows.
    final dairyName =
        readOnly ? ref.watch(ownerProfileProvider(account.ownerUid)).value?.dairyName : null;

    return bills.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(
        message: 'Could not load the bills.',
        onRetry: () => ref.invalidate(billsProvider(account.ref)),
      ),
      data: (state) {
        final bill = state.current;

        if (bill == null) {
          return Column(children: [
            BillHeader(account: account, bill: null, dairyName: dairyName, menu: headerMenu),
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

        return DefaultTabController(
          length: Session.values.length,
          // Open on the session that matches the time of day.
          initialIndex: DateTime.now().hour < 15 ? 0 : 1,
          child: Column(
            children: [
              BillHeader(account: account, bill: bill, dairyName: dairyName, menu: headerMenu),
              TabBar(tabs: [for (final s in Session.values) Tab(text: s.label)]),
              Expanded(
                child: TabBarView(
                  children: [
                    for (final session in Session.values)
                      _SessionTable(
                        bill: bill,
                        session: session,
                        onRefresh: notifier.refresh,
                        onRowTap: readOnly
                            ? null
                            : (date) => _editSlot(context, ref, bill, date, session, rateFor),
                      ),
                  ],
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
          ),
        );
      },
    );
  }

  /// Range picker, then create the bill. Overlaps are rejected with a message.
  Future<void> _addWeek(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(billsProvider(account.ref).notifier);
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

  /// Opens the slot dialog for a row and saves the result.
  Future<void> _editSlot(
    BuildContext context,
    WidgetRef ref,
    Bill bill,
    DateTime date,
    Session session,
    double? Function(double fat) rateFor,
  ) async {
    final slot = await showSlotDialog(
      context,
      date: date,
      sessionLabel: session.label,
      slot: bill.slot(date, session),
      rateFor: rateFor,
    );
    if (slot == null || !context.mounted) return;
    _onSlotChanged(context, ref, date, session, slot);
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
    ref.read(billsProvider(account.ref).notifier).saveSlot(date, session, slot);

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
    ref.read(billsProvider(account.ref).notifier).saveSlot(
          date,
          session,
          BillSlot(milk: slot.milk, fat: slot.fat, rate: result.rate),
        );
  }
}

/// The table of one session: header, one row per day, session total.
class _SessionTable extends StatelessWidget {
  const _SessionTable({
    required this.bill,
    required this.session,
    required this.onRefresh,
    required this.onRowTap,
  });

  final Bill bill;
  final Session session;
  final Future<void> Function() onRefresh;

  /// Null on the read-only supplier screen.
  final ValueChanged<DateTime>? onRowTap;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const BillTableHeader(),
          const Divider(),
          for (final date in bill.dates) ...[
            BillDayRow(
              date: date,
              slot: bill.slot(date, session),
              onTap: onRowTap == null ? null : () => onRowTap!(date),
            ),
            const Divider(),
          ],
          BillTotalRow(milk: bill.sessionMilk(session), amount: bill.sessionAmount(session)),
        ],
      ),
    );
  }
}
