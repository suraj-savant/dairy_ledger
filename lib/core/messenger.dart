import 'package:flutter/material.dart';

/// Lets non-UI code (for example a failed background write) show a snack bar.
/// Attached to `MaterialApp.scaffoldMessengerKey`.
final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void showAppSnack(String message) {
  rootMessengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
