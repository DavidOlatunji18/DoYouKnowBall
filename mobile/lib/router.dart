import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth/session.dart';
import 'screens/app_shell.dart';
import 'screens/auth_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/tab_screens.dart';
import 'screens/welcome_screen.dart';

const _signedOutRoutes = {'/welcome', '/signup', '/login'};

/// The app starts on the splash screen until the saved login has been checked.
/// After that, signed-out players can only see Welcome, Sign up and Log in, and
/// signed-in players skip those and land on Home. Re-checked whenever the session
/// changes, so logging in or out moves the player automatically.
///
/// Signed-in screens live in four tabs (Home, Challenge, Leaderboard, Profile) under
/// a shared nav bar; the quiz opens full-screen on top of them.
GoRouter createRouter(Session session) => GoRouter(
  initialLocation: '/splash',
  refreshListenable: session,
  redirect: (context, state) {
    final location = state.matchedLocation;
    if (!session.ready) return location == '/splash' ? null : '/splash';
    if (location == '/splash') return session.isLoggedIn ? '/home' : '/welcome';

    final signedOutRoute = _signedOutRoutes.contains(location);
    if (!session.isLoggedIn && !signedOutRoute) return '/welcome';
    if (session.isLoggedIn && signedOutRoute) return '/home';
    return null;
  },
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/welcome',
      pageBuilder: (context, state) => _fade(state, const WelcomeScreen()),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) =>
          const AuthScreen(initialMode: AuthMode.signUp),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) =>
          const AuthScreen(initialMode: AuthMode.logIn),
    ),
    StatefulShellRoute.indexedStack(
      pageBuilder: (context, state, shell) =>
          _fade(state, AppShell(navigationShell: shell)),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
              routes: [
                GoRoute(
                  path: 'sport/:sportId',
                  builder: (context, state) => CategoriesScreen(
                    sportId: int.parse(state.pathParameters['sportId']!),
                    sportName: state.uri.queryParameters['name'] ?? 'Sport',
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/challenge',
              builder: (context, state) => const ChallengeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/leaderboard',
              builder: (context, state) => const LeaderboardScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/play/:categoryId',
      builder: (context, state) => QuizPlaceholderScreen(
        categoryName: state.uri.queryParameters['name'] ?? 'Category',
      ),
    ),
  ],
);

/// Screens reached by a redirect (splash finishing, logging in or out) fade in
/// rather than sliding, since there's nothing to go "back" to.
CustomTransitionPage<void> _fade(GoRouterState state, Widget child) =>
    CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 350),
      transitionsBuilder: (context, animation, secondary, child) =>
          FadeTransition(opacity: animation, child: child),
    );
