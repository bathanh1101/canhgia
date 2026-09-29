import 'package:flutter/material.dart';

import 'app_top_bar.dart';
import 'empty_state.dart';

/// Temporary body for routes whose feature has not been built yet (handoff stubs).
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppTopBar(title: title),
        body: const EmptyState(message: 'Tính năng đang được xây dựng.', icon: Icons.construction_outlined),
      );
}
