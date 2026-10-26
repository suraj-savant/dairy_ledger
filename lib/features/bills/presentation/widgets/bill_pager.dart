import 'package:flutter/material.dart';
import '../../providers/bill_providers.dart';

/// `Previous week` and `Next` / `Add week` buttons under the table.
///
/// On the newest bill the second button reads "Add week" (admin only);
/// on older bills it reads "Next".
class BillPager extends StatelessWidget {
  const BillPager({
    super.key,
    required this.state,
    required this.canAdd,
    required this.onPrevious,
    required this.onNext,
    required this.onAdd,
  });

  final BillsState state;
  final bool canAdd;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final showAdd = state.isLatest && canAdd;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: state.canGoPrevious && !state.loadingMore ? onPrevious : null,
              child: state.loadingMore
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const FittedBox(child: Text('Previous week')),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: showAdd
                ? ElevatedButton(onPressed: onAdd, child: const FittedBox(child: Text('Add week')))
                : ElevatedButton(
                    onPressed: state.isLatest ? null : onNext,
                    child: const FittedBox(child: Text('Next')),
                  ),
          ),
        ],
      ),
    );
  }
}
