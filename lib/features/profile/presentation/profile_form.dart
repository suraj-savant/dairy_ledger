import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/widgets/dialogs.dart';
import '../models/user_profile.dart';

/// The three onboarding questions (name, dairy name, bill cycle). Used by the
/// onboarding screen and again by Settings so the answers can be changed.
class ProfileForm extends StatefulWidget {
  const ProfileForm({
    super.key,
    required this.initial,
    required this.submitLabel,
    required this.onSubmit,
  });

  final UserProfile initial;
  final String submitLabel;
  final void Function(String adminName, String dairyName, int billCycleDays) onSubmit;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.initial.adminName);
  late final TextEditingController _dairy =
      TextEditingController(text: widget.initial.dairyName);
  late int _cycle = widget.initial.billCycleDays;

  @override
  void dispose() {
    _name.dispose();
    _dairy.dispose();
    super.dispose();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'This field is required' : null;

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    widget.onSubmit(_name.text.trim(), _dairy.text.trim(), _cycle);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Your name'),
            validator: _required,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _dairy,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: 'Dairy name'),
            validator: _required,
          ),
          const SizedBox(height: 32),
          Text('Billing cycle', style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            'Number of days in one bill',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          CycleStepper(
            value: _cycle,
            min: AppConstants.minBillCycleDays,
            max: AppConstants.maxBillCycleDays,
            onChanged: (v) => setState(() => _cycle = v),
          ),
          const SizedBox(height: 32),
          ElevatedButton(onPressed: _submit, child: Text(widget.submitLabel)),
        ],
      ),
    );
  }
}
