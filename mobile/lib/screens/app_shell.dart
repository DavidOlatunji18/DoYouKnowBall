import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../widgets/app_nav_bar.dart';

/// Wraps the four tabs with the floating nav bar. Each tab keeps its own
/// navigation stack, so switching tabs and back returns to where you were.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        // Content scrolls behind the floating dock.
        extendBody: true,
        body: navigationShell,
        bottomNavigationBar: AppNavBar(
          items: AppNavBar.tabs,
          currentIndex: navigationShell.currentIndex,
          // Tapping the current tab again goes back to its first screen.
          onSelect: (i) => navigationShell.goBranch(
            i,
            initialLocation: i == navigationShell.currentIndex,
          ),
        ),
      ),
    );
  }
}
