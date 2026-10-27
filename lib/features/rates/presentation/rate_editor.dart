import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/fat.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/dialogs.dart';
import '../models/rate_chart.dart';
import '../providers/rate_providers.dart';
import 'fat_dialog.dart';

/// Edit mode of the Rates tab: every rate becomes an input, fats can be added
/// or deleted (checkbox + delete), and everything is saved at once.
///
/// The edits live only in this widget (a draft). Nothing reaches the rate
/// chart, the bills or Firestore until Save, which writes one document update.
class RateEditor extends ConsumerStatefulWidget {
  const RateEditor({super.key, required this.chart});

  final RateChart chart;

  @override
  ConsumerState<RateEditor> createState() => _RateEditorState();
}

class _RateEditorState extends ConsumerState<RateEditor> {
  /// Draft: fat key -> rate input.
  late final Map<String, TextEditingController> _rates = {
    for (final e in widget.chart.fats.entries)
      e.key: TextEditingController(text: Fmt.rate(e.value)),
  };

  /// Controllers of deleted rows, disposed with the editor (a row may still be
  /// on screen for one more frame after it is deleted).
  final List<TextEditingController> _retired = [];

  /// Fat keys ticked for deletion.
  final Set<String> _selected = {};

  @override
  void dispose() {
    for (final c in [..._rates.values, ..._retired]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _keys =>
      _rates.keys.toList()
        ..sort((a, b) => (Fat.parse(a) ?? 0).compareTo(Fat.parse(b) ?? 0));

  /// The draft as fat key -> rate (an empty input counts as 0).
  Map<String, double> _draft() => {
    for (final e in _rates.entries) e.key: Fmt.parseNum(e.value.text) ?? 0,
  };

  bool get _dirty {
    final original = widget.chart.fats;
    final draft = _draft();
    return draft.length != original.length ||
        draft.entries.any((e) => original[e.key] != e.value);
  }

  void _exit() => ref.read(ratesEditingProvider.notifier).set(false);

  Future<void> _cancel() async {
    if (_dirty) {
      final discard = await confirm(
        context,
        title: 'Discard changes?',
        message: 'Your edits to this rate chart will be lost.',
        confirmLabel: 'Discard',
      );
      if (!discard) return;
    }
    _exit();
  }

  void _save() {
    if (_dirty) {
      ref
          .read(ratesProvider.notifier)
          .saveChart(widget.chart.category, _draft());
    }
    _exit();
  }

  Future<void> _addFat() async {
    final result = await showFatDialog(context, title: 'Add fat');
    if (result == null) return;
    final key = Fat.key(result.fat);
    final text = Fmt.rate(result.rate);
    setState(() {
      final existing = _rates[key];
      if (existing != null) {
        existing.text = text; // the fat is already in the chart: update it
      } else {
        _rates[key] = TextEditingController(text: text);
      }
    });
  }

  void _deleteSelected() {
    setState(() {
      for (final key in _selected) {
        _retired.add(_rates.remove(key)!);
      }
      _selected.clear();
    });
  }

  void _toggleAll(bool all) {
    setState(() {
      _selected
        ..clear()
        ..addAll(all ? _rates.keys : const []);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keys = _keys;
    final allSelected = keys.isNotEmpty && _selected.length == keys.length;

    return PopScope(
      canPop: false, // back asks before throwing edits away
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Cancel',
            onPressed: _cancel,
          ),
          title: Text('Edit ${widget.chart.category}'),
          actions: [
            if (_selected.isNotEmpty)
              TextButton.icon(
                onPressed: _deleteSelected,
                icon: const Icon(Icons.delete_outline),
                label: Text('Delete (${_selected.length})'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Add fat',
                onPressed: _addFat,
              ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
              child: Row(
                children: [
                  ExcludeFocus(
                    child: Checkbox(
                      value: allSelected,
                      onChanged: keys.isEmpty
                          ? null
                          : (v) => _toggleAll(v ?? false),
                    ),
                  ),
                  Expanded(
                    child: Text('FAT', style: theme.textTheme.labelLarge),
                  ),
                  Text('RATE', style: theme.textTheme.labelLarge),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: keys.isEmpty
                  ? const Center(child: Text('No fats. Tap + to add one.'))
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: keys.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (context, i) {
                        final key = keys[i];
                        return Container(
                          key: ValueKey(key),
                          constraints: const BoxConstraints(minHeight: 56),
                          padding: const EdgeInsets.fromLTRB(8, 0, 24, 0),
                          child: Row(
                            children: [
                              ExcludeFocus(
                                child: Checkbox(
                                  value: _selected.contains(key),
                                  onChanged: (v) => setState(() {
                                    v == true
                                        ? _selected.add(key)
                                        : _selected.remove(key);
                                  }),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  key,
                                  style: theme.textTheme.bodyLarge,
                                ),
                              ),
                              _RateField(controller: _rates[key]!),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cancel,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small, plain rate input (underline only, no fill). A rate of 0.0 is cleared
/// when the field gets focus, and an empty or half-typed value goes back to a
/// clean number (`0.0`, `52.0`) when focus leaves.
class _RateField extends StatefulWidget {
  const _RateField({required this.controller});

  final TextEditingController controller;

  @override
  State<_RateField> createState() => _RateFieldState();
}

class _RateFieldState extends State<_RateField> {
  late final FocusNode _focus = FocusNode()..addListener(_onFocusChange);

  static final _decimal = [
    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
  ];

  void _onFocusChange() {
    final c = widget.controller;
    if (_focus.hasFocus) {
      if ((Fmt.parseNum(c.text) ?? 0) == 0) {
        c.clear();
      } else {
        c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);
      }
    } else {
      c.text = Fmt.rate(Fmt.parseNum(c.text) ?? 0);
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 88,
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        textAlign: TextAlign.end,
        textInputAction: TextInputAction.next,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: _decimal,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          border: UnderlineInputBorder(
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: scheme.primary, width: 2),
          ),
        ),
      ),
    );
  }
}
