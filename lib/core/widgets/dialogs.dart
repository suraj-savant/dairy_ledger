import 'package:flutter/material.dart';

/// Yes/No confirmation. Returns true only when the user confirms.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          style: destructive
              ? TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Number stepper `<  7  >` used for the bill cycle (onboarding and settings).
class CycleStepper extends StatelessWidget {
  const CycleStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton.filledTonal(
          iconSize: 28,
          constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Fewer days',
        ),
        SizedBox(
          width: 96,
          child: Column(
            children: [
              Text('$value', style: theme.textTheme.headlineLarge),
              Text(value == 1 ? 'day' : 'days', style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
        IconButton.filledTonal(
          iconSize: 28,
          constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.chevron_right),
          tooltip: 'More days',
        ),
      ],
    );
  }
}
