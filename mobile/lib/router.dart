import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth/session.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';

const _signedOutRoutes = {'/welcome', '/signup', '/login'};

/// The app starts on the splash screen until the saved login has been checked.
/// After that, signed-out players can only see Welcome, Sign up and Log in, and
/// signed-in players skip those and land on Home. Re-checked whenever the session
/// changes, so logging in or out moves the player automatically.
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
    GoRoute(
      path: '/home',
      pageBuilder: (context, state) => _fade(state, const HomeScreen()),
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
