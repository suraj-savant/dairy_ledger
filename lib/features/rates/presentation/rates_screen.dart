import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/messenger.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/state_views.dart';
import '../models/rate_chart.dart';
import '../providers/rate_providers.dart';
import 'fat_dialog.dart';
import 'rate_editor.dart';

/// Rates tab: pick a category (cow, buffalo, ...), see and edit its fat -> rate list.
class RatesScreen extends ConsumerWidget {
  const RatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charts = ref.watch(ratesProvider);
    final selected = ref.watch(selectedCategoryProvider);
    final editing = ref.watch(ratesEditingProvider);

    return charts.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Rates')),
        body: const LoadingView(),
      ),
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

        if (editing && chart != null) {
          return RateEditor(key: ValueKey(chart.category), chart: chart);
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Rates'),
            actions: [
              if (chart != null)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit rates',
                  onPressed: () =>
                      ref.read(ratesEditingProvider.notifier).set(true),
                ),
              if (chart != null)
                PopupMenuButton<String>(
                  onSelected: (_) =>
                      _deleteCategory(context, ref, chart.category),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete category'),
                    ),
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
              : _RateList(
                  chart: chart,
                  names: names,
                  onAddCategory: () => _addCategory(context, ref),
                ),
        );
      },
    );
  }

  Future<void> _addCategory(BuildContext context, WidgetRef ref) async {
    final name = await showTextDialog(
      context,
      title: 'New category',
      label: 'Name (e.g. COW)',
    );
    if (name == null || name.isEmpty) return;
    if (!ref.read(ratesProvider.notifier).createCategory(name)) {
      showAppSnack('That category already exists.');
    }
  }

  Future<void> _deleteCategory(
    BuildContext context,
    WidgetRef ref,
    String category,
  ) async {
    final ok = await confirm(
      context,
      title: 'Delete $category?',
      message: 'The rate chart will be removed. Bills already saved keep their rates.',
    );
    if (ok) ref.read(ratesProvider.notifier).deleteCategory(category);
  }
}

class _RateList extends ConsumerWidget {
  const _RateList({
    required this.chart,
    required this.names,
    required this.onAddCategory,
  });

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
                  items: [
                    for (final n in names)
                      DropdownMenuItem(value: n, child: Text(n)),
                  ],
                  onChanged: (v) =>
                      ref.read(selectedCategoryProvider.notifier).select(v),
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
              Expanded(
                child: Text(
                  'RATE',
                  style: theme.textTheme.labelLarge,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: rows.isEmpty
              ? const Center(child: Text('No fats. Tap Edit to add one.'))
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, i) {
                    final rate = rows[i].value;
                    return Container(
                      constraints: const BoxConstraints(minHeight: 56),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              rows[i].key,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                          Text(
                            Fmt.rate(rate),
                            style: theme.textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
