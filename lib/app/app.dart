import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/messenger.dart';
import 'router.dart';
import 'theme.dart';

/// Root widget: theme, router and the global snack-bar messenger.
class DairyLedgerApp extends ConsumerWidget {
  const DairyLedgerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      scaffoldMessengerKey: rootMessengerKey,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
