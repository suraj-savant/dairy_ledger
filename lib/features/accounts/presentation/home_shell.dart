import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../rates/providers/rate_providers.dart';

/// Bottom navigation (Home | Rates | Analytics) around the three tab screens.
/// Each tab keeps its own state (see `StatefulShellRoute` in the router).
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rates edit mode hides the tabs until Save or Cancel.
    final editingRates = ref.watch(ratesEditingProvider);
    return Scaffold(
      body: shell,
      bottomNavigationBar: editingRates
          ? null
          : NavigationBar(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: (i) =>
                  shell.goBranch(i, initialLocation: i == shell.currentIndex),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.price_change_outlined),
                  selectedIcon: Icon(Icons.price_change),
                  label: 'Rates',
                ),
                NavigationDestination(
                  icon: Icon(Icons.insights_outlined),
                  selectedIcon: Icon(Icons.insights),
                  label: 'Analytics',
                ),
              ],
            ),
    );
  }
}
