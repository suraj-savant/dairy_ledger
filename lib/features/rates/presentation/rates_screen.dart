import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/messenger.dart';
import '../../../core/utils/fat.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/state_views.dart';
import '../models/rate_chart.dart';
import '../providers/rate_providers.dart';
import 'fat_dialog.dart';

/// Rates tab: pick a category (cow, buffalo, ...), see and edit its fat -> rate list.
class RatesScreen extends ConsumerWidget {
  const RatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charts = ref.watch(ratesProvider);
    final selected = ref.watch(selectedCategoryProvider);

    return charts.when(
      loading: () => Scaffold(appBar: AppBar(title: const Text('Rates')), body: const LoadingView()),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Rates')),
        body: ErrorView(
          message: 'Could not load the rates.',
          onRetry: () => ref.invalidate(ratesProvider),
        ),
      ),
      data: (map) {
        final names = map.keys.toList()..sort();
        final current = (selected != null && map.containsKey(selected))
            ? selected
            : (names.isEmpty ? null : names.first);
        final chart = current == null ? null : map[current];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Rates'),
            actions: [
              if (chart != null)
                PopupMenuButton<String>(
                  onSelected: (_) => _deleteCategory(context, ref, chart.category),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'delete', child: Text('Delete category')),
                  ],
                ),
            ],
          ),
          body: chart == null
              ? EmptyView(
                  icon: Icons.price_change_outlined,
                  message: 'Add a milk category (for example COW) to set your rates.',
                  actionLabel: 'Add category',
                  onAction: () => _addCategory(context, ref),
                )
              : _RateList(chart: chart, names: names, onAddCategory: () => _addCategory(context, ref)),
          floatingActionButton: chart == null
              ? null
              : FloatingActionButton(
                  onPressed: () => _addFat(context, ref, chart.category),
                  tooltip: 'Add fat',
                  child: const Icon(Icons.add),
                ),
        );
      },
    );
  }

  Future<void> _addCategory(BuildContext context, WidgetRef ref) async {
    final name = await showTextDialog(context, title: 'New category', label: 'Name (e.g. COW)');
    if (name == null || name.isEmpty) return;
    if (!ref.read(ratesProvider.notifier).createCategory(name)) {
      showAppSnack('That category already exists.');
    }
  }

  Future<void> _deleteCategory(BuildContext context, WidgetRef ref, String category) async {
    final ok = await confirm(
      context,
      title: 'Delete $category?',
      message: 'The rate chart will be removed. Bills already saved keep their rates.',
    );
    if (ok) ref.read(ratesProvider.notifier).deleteCategory(category);
  }

  Future<void> _addFat(BuildContext context, WidgetRef ref, String category) async {
    final result = await showFatDialog(context, title: 'Add fat');
    if (result == null) return;
    ref.read(ratesProvider.notifier).setFat(category, result.fat, result.rate);
  }
}

class _RateList extends ConsumerWidget {
  const _RateList({required this.chart, required this.names, required this.onAddCategory});

  final RateChart chart;
  final List<String> names;
  final VoidCallback onAddCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rows = chart.sorted;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: chart.category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [for (final n in names) DropdownMenuItem(value: n, child: Text(n))],
                  onChanged: (v) => ref.read(selectedCategoryProvider.notifier).select(v),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: onAddCategory,
                icon: const Icon(Icons.add),
                tooltip: 'Add category',
                constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              Expanded(child: Text('FAT', style: theme.textTheme.labelLarge)),
              Expanded(child: Text('RATE', style: theme.textTheme.labelLarge, textAlign: TextAlign.end)),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, i) {
              final fatKey = rows[i].key;
              final rate = rows[i].value;
              final isSet = rate > 0;
              return InkWell(
                onTap: () => _editRate(context, ref, fatKey, rate),
                onLongPress: Fat.isCustom(fatKey) ? () => _removeFat(context, ref, fatKey) : null,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(fatKey, style: theme.textTheme.bodyLarge),
                            if (Fat.isCustom(fatKey)) ...[
                              const SizedBox(width: 8),
                              Chip(
                                label: const Text('custom'),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                backgroundColor: AppTheme.deepPurpleContainer,
                                side: BorderSide.none,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        isSet ? Fmt.num(rate) : 'not set',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: isSet ? null : AppTheme.amberHighlight,
                          fontWeight: isSet ? FontWeight.w600 : FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Long-press on a custom fat removes it (the default 3.0 .. 10.0 rows stay).
  Future<void> _removeFat(BuildContext context, WidgetRef ref, String fatKey) async {
    final ok = await confirm(
      context,
      title: 'Remove fat $fatKey?',
      message: 'Bills already saved keep their rates.',
      confirmLabel: 'Remove',
    );
    if (ok) ref.read(ratesProvider.notifier).removeFat(chart.category, fatKey);
  }

  Future<void> _editRate(BuildContext context, WidgetRef ref, String fatKey, double rate) async {
    final result = await showFatDialog(
      context,
      title: 'Edit rate',
      fat: Fat.parse(fatKey),
      rate: rate,
      fatLocked: true,
    );
    if (result == null) return;
    ref.read(ratesProvider.notifier).setFat(chart.category, result.fat, result.rate);
  }
}
