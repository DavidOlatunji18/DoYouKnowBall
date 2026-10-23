import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/session.dart';
import '../theme.dart';
import '../widgets/chunky_button.dart';
import '../widgets/marker_headline.dart';

/// Temporary Home: confirms the login worked. The sport picker replaces this
/// once its design is ready.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final name = session.user?.displayName ?? 'baller';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              MarkerHeadline(lead: "You're in,", marked: '@$name.'),
              const SizedBox(height: 12),
              Text(
                'Home and the sport picker are coming next.',
                style: appFont(16.5, weight: 500, color: AppColors.muted),
              ),
              const Spacer(),
              ChunkyButton(
                label: 'Log out',
                color: AppColors.card,
                onPressed: session.signOut,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
