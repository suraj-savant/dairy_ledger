import 'package:flutter/material.dart';

import '../../../core/widgets/state_views.dart';

/// Placeholder: analytics is planned after the first release.
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Analytics')),
        body: const EmptyView(
          icon: Icons.insights_outlined,
          message: 'Analytics is coming soon.',
        ),
      );
}
