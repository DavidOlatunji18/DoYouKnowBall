import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dykb/widgets/app_nav_bar.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

/// A logged-in app whose fake API serves two sports and NFL's categories.
Future<TestApp> loggedInApp({
  bool sportsFail = false,
  List<Map<String, dynamic>> history = const [],
}) async {
  var failSports = sportsFail;
  final app = TestApp((RequestOptions request) {
    switch (request.path) {
      case '/me':
        return jsonResponse(200, {
          'id': 1,
          'email': 'k@b.co',
          'displayName': 'kobe24',
        });
      case '/sports':
        if (failSports) {
          failSports = false; // fail once, then succeed on retry
          throw DioException.connectionError(
            requestOptions: request,
            reason: 'offline',
          );
        }
        return jsonResponse(200, [
          {'id': 2, 'name': 'NFL'},
          {'id': 3, 'name': 'Soccer'},
        ]);
      case '/games/history':
        return jsonResponse(200, history);
      case '/sports/2/categories':
        return jsonResponse(200, [
          {'id': 10, 'name': 'History', 'sportId': 2},
          {'id': 11, 'name': 'Players', 'sportId': 2},
        ]);
    }
    return jsonResponse(404, {'error': 'Not found'});
  });
  await app.store.write('auth_token', 'saved-token');
  await app.store.write(
    'auth_user',
    jsonEncode({'id': 1, 'email': 'k@b.co', 'displayName': 'kobe24'}),
  );
  return app;
}

void main() {
  testWidgets('Home greets the player and lists the sports', (tester) async {
    usePhoneScreen(tester);
    await launch(tester, await loggedInApp());

    expect(find.bySemanticsLabel('Welcome @kobe24'), findsOneWidget);
    expect(find.text('Football'), findsOneWidget);
    expect(find.text('Soccer'), findsOneWidget);
    expect(find.text('History, records & players'), findsOneWidget);
    expect(find.byType(AppNavBar), findsOneWidget);
  });

  testWidgets('Sports without questions show as coming soon', (tester) async {
    usePhoneScreen(tester);
    await launch(tester, await loggedInApp());

    for (final name in ['Basketball', 'Baseball', 'Hockey']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('Coming soon'), findsNWidgets(3));

    await tester.tap(find.text('Basketball'));
    await tester.pump();
    expect(
      find.text('Basketball trivia is coming soon. Stay tuned!'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5)); // let the snackbar finish
  });

  testWidgets(
    'Every tab has the logo header, and the nav bar shows icons only',
    (tester) async {
      usePhoneScreen(tester);
      await launch(tester, await loggedInApp());

      for (final tab in ['Home', 'Challenge', 'Leaderboard', 'Profile']) {
        await tester.tap(find.bySemanticsLabel(tab));
        await settle(tester);
        expect(find.text('dykb?'), findsWidgets, reason: '$tab tab');
        expect(
          find.descendant(of: find.byType(AppNavBar), matching: find.text(tab)),
          findsNothing,
        );
      }
    },
  );

  testWidgets(
    'Picking a sport shows its categories, and Play opens the quiz full-screen',
    (tester) async {
      usePhoneScreen(tester);
      await launch(tester, await loggedInApp());

      await tester.tap(find.text('Football'));
      await settleRequest(tester);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Players'), findsOneWidget);
      expect(
        find.byType(AppNavBar),
        findsOneWidget,
        reason: 'categories stay inside the Home tab',
      );

      await tester.tap(find.text('Players'));
      await settle(tester);
      expect(find.bySemanticsLabel('Do you know ball?'), findsOneWidget);
      expect(
        find.byType(AppNavBar),
        findsNothing,
        reason: 'the quiz is full-screen',
      );
    },
  );

  testWidgets(
    'The tabs switch between Home, Challenge, Leaderboard and Profile',
    (tester) async {
      usePhoneScreen(tester);
      await launch(tester, await loggedInApp());

      await tester.tap(find.bySemanticsLabel('Challenge'));
      await settle(tester);
      expect(find.text('friend.'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Leaderboard'));
      await settle(tester);
      expect(find.bySemanticsLabel('Who knows ball?'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Profile'));
      await settle(tester);
      expect(find.text('@kobe24'), findsOneWidget);
      expect(find.text('k@b.co'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Home'));
      await settle(tester);
      expect(find.bySemanticsLabel('Welcome @kobe24'), findsOneWidget);
    },
  );

  testWidgets('A failed load shows a friendly message and Try again works', (
    tester,
  ) async {
    usePhoneScreen(tester);
    final app = await loggedInApp(sportsFail: true);
    await launch(tester, app);

    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );
    await tester.tap(find.text('Try again'));
    await settleRequest(tester);

    expect(find.text('Football'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('Logging out from Profile returns to Welcome', (tester) async {
    usePhoneScreen(tester);
    final app = await loggedInApp();
    await launch(tester, app);

    await tester.tap(find.bySemanticsLabel('Profile'));
    await settle(tester);
    await tester.tap(find.text('Log out'));
    await settleRequest(tester);

    expect(app.session.isLoggedIn, isFalse);
    expect(find.byType(AppNavBar), findsNothing);
    expect(find.text('Sign up'), findsOneWidget);
  });
}
