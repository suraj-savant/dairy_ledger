import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants.dart';

/// Six separate digit boxes backed by one hidden text field, so paste,
/// SMS auto-fill and the numeric keyboard all work. Calls [onCompleted]
/// once all digits are entered. Use a `GlobalKey<OtpInputState>` to [clear] it.
class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    required this.onCompleted,
    this.onChanged,
    this.enabled = true,
  });

  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  State<OtpInput> createState() => OtpInputState();
}

class OtpInputState extends State<OtpInput> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {});
    widget.onChanged?.call(_controller.text);
    if (_controller.text.length == AppConstants.otpLength) {
      widget.onCompleted(_controller.text);
    }
  }

  /// Clears the boxes (after a wrong code).
  void clear() => _controller.clear();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = _controller.text;

    return GestureDetector(
      onTap: () => _focus.requestFocus(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(AppConstants.otpLength, (i) {
              final active = _focus.hasFocus && i == text.length.clamp(0, AppConstants.otpLength - 1);
              return Container(
                width: 48,
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active ? theme.colorScheme.primary : theme.colorScheme.outline,
                    width: active ? 2 : 1,
                  ),
                ),
                child: Text(
                  i < text.length ? text[i] : '',
                  style: theme.textTheme.headlineMedium,
                ),
              );
            }),
          ),
          // The real input: invisible but focusable and auto-fill capable.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                autofocus: true,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(AppConstants.otpLength),
                ],
                showCursor: false,
                enableInteractiveSelection: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
