import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import 'profile_fields.dart';

/// Result of [showEditProfileDialog].
typedef ProfileInput = ({String adminName, String dairyName, int billCycleDays});

/// Dialog used by Settings to change the onboarding answers. Returns null
/// when cancelled.
Future<ProfileInput?> showEditProfileDialog(BuildContext context, UserProfile initial) {
  return showDialog<ProfileInput>(
    context: context,
    builder: (_) => _EditProfileDialog(initial: initial),
  );
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({required this.initial});
  final UserProfile initial;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial.adminName);
  late final _dairy = TextEditingController(text: widget.initial.dairyName);
  late final _cycle = TextEditingController(text: '${widget.initial.billCycleDays}');

  @override
  void dispose() {
    _name.dispose();
    _dairy.dispose();
    _cycle.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(context, (
      adminName: _name.text.trim(),
      dairyName: _dairy.text.trim(),
      billCycleDays: int.parse(_cycle.text.trim()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit details'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: ProfileFields(name: _name, dairy: _dairy, cycle: _cycle, onSubmitted: _save),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
