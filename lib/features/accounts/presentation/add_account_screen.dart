import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/state_views.dart';
import '../../rates/providers/rate_providers.dart';
import '../providers/account_providers.dart';

/// Add a supplier / customer: a name and the milk category (rate chart) to use.
class AddAccountScreen extends ConsumerStatefulWidget {
  const AddAccountScreen({super.key});

  @override
  ConsumerState<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends ConsumerState<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  String? _category;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    ref.read(accountsProvider.notifier).create(name: _name.text, category: _category!);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final charts = ref.watch(ratesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Add account')),
      body: charts.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'Could not load the categories.',
          onRetry: () => ref.invalidate(ratesProvider),
        ),
        data: (map) {
          if (map.isEmpty) {
            // An account needs a rate chart, so a category must exist first.
            return EmptyView(
              icon: Icons.price_change_outlined,
              message: 'Add a milk category in the Rates tab first.',
              actionLabel: 'Go to Rates',
              onAction: () => context.go('/rates'),
            );
          }
          final names = map.keys.toList()..sort();
          _category ??= names.first;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _name,
                      autofocus: true,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Account name'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter a name';
                        if (ref.read(accountsProvider.notifier).exists(v)) {
                          return 'An account with this name already exists';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: const InputDecoration(labelText: 'Milk category'),
                      items: [for (final n in names) DropdownMenuItem(value: n, child: Text(n))],
                      onChanged: (v) => setState(() => _category = v),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(onPressed: _save, child: const Text('SAVE')),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
