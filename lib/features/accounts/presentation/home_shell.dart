import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottom navigation (Home | Rates | Analytics) around the three tab screens.
/// Each tab keeps its own state (see `StatefulShellRoute` in the router).
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.price_change_outlined),
              selectedIcon: Icon(Icons.price_change),
              label: 'Rates'),
          NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'Analytics'),
        ],
      ),
    );
  }
}
