import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants.dart';

/// The three profile questions as plain text inputs: name, dairy name and
/// bill cycle (days). Shared by the onboarding screen and the Settings
/// edit dialog; the parent owns the controllers and the [Form].
class ProfileFields extends StatelessWidget {
  const ProfileFields({
    super.key,
    required this.name,
    required this.dairy,
    required this.cycle,
    this.onSubmitted,
  });

  final TextEditingController name;
  final TextEditingController dairy;
  final TextEditingController cycle;
  final VoidCallback? onSubmitted;

  static String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'This field is required' : null;

  static String? _cycle(String? v) {
    final n = int.tryParse((v ?? '').trim());
    if (n == null) return 'Enter the number of days';
    if (n < AppConstants.minBillCycleDays || n > AppConstants.maxBillCycleDays) {
      return 'Enter ${AppConstants.minBillCycleDays} to ${AppConstants.maxBillCycleDays} days';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Your name'),
          validator: _required,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: dairy,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Dairy name'),
          validator: _required,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: cycle,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          decoration: const InputDecoration(
            labelText: 'Billing cycle (days)',
            helperText: 'Number of days in one bill. Default is 7.',
          ),
          validator: _cycle,
          onFieldSubmitted: (_) => onSubmitted?.call(),
        ),
      ],
    );
  }
}
