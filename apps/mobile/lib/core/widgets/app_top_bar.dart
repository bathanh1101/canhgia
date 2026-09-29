import 'package:flutter/material.dart';

/// Standard screen app bar; back button appears automatically when the route can pop.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({super.key, required this.title, this.actions});

  final String title;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(title: Text(title), centerTitle: true, actions: actions);
}
