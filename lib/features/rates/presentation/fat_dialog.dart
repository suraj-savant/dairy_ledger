import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/fat.dart';
import '../../../core/utils/formatters.dart';

/// Result of [showFatDialog].
typedef FatRate = ({double fat, double rate});

/// Dialog to add or edit one fat -> rate pair.
///
/// * add:   leave [fat] null.
/// * edit:  pass [fat] and [rate]; [fatLocked] stops the fat from changing.
/// * add from a bill (missing rate): pass [fat] with [fatLocked] true.
Future<FatRate?> showFatDialog(
  BuildContext context, {
  required String title,
  double? fat,
  double? rate,
  bool fatLocked = false,
}) {
  return showDialog<FatRate>(
    context: context,
    builder: (_) => _FatDialog(title: title, fat: fat, rate: rate, fatLocked: fatLocked),
  );
}

class _FatDialog extends StatefulWidget {
  const _FatDialog({required this.title, this.fat, this.rate, required this.fatLocked});
  final String title;
  final double? fat;
  final double? rate;
  final bool fatLocked;

  @override
  State<_FatDialog> createState() => _FatDialogState();
}

class _FatDialogState extends State<_FatDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _fat = TextEditingController(text: widget.fat == null ? '' : Fat.key(widget.fat!));
  late final _rate = TextEditingController(
      text: (widget.rate == null || widget.rate == 0) ? '' : Fmt.num(widget.rate!));

  @override
  void dispose() {
    _fat.dispose();
    _rate.dispose();
    super.dispose();
  }

  static final _decimal = [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))];

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(context, (fat: Fmt.parseNum(_fat.text)!, rate: Fmt.parseNum(_rate.text)!));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _fat,
              enabled: !widget.fatLocked,
              autofocus: widget.fat == null,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: _decimal,
              decoration: const InputDecoration(labelText: 'Fat'),
              validator: (v) {
                final n = Fmt.parseNum(v ?? '');
                if (n == null || n <= 0) return 'Enter the fat';
                if (n > 20) return 'Fat looks too high';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _rate,
              autofocus: widget.fat != null,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: _decimal,
              decoration: const InputDecoration(labelText: 'Rate per litre'),
              validator: (v) {
                final n = Fmt.parseNum(v ?? '');
                return (n == null || n <= 0) ? 'Enter the rate' : null;
              },
              onFieldSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

/// Single text-field dialog (used for the category name).
Future<String?> showTextDialog(
  BuildContext context, {
  required String title,
  required String label,
  String confirmLabel = 'Add',
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(labelText: label),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}
