import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

Map<String, dynamic> entry(int rank, String name, int best, int games) => {
  'rank': rank,
  'displayName': name,
  'bestScore': best,
  'gamesPlayed': games,
};

/// A logged-in app (as @kobe24) whose fake API serves the given boards by sport id:
/// NFL is sport 2, Soccer is sport 3.
Future<TestApp> leaderboardApp({
  List<Map<String, dynamic>> nfl = const [],
  List<Map<String, dynamic>> soccer = const [],
}) async {
  final app = TestApp((RequestOptions request) {
    switch (request.path) {
      case '/me':
        return jsonResponse(200, {
          'id': 1,
          'email': 'k@b.co',
          'displayName': 'kobe24',
        });
      case '/sports':
        return jsonResponse(200, [
          {'id': 2, 'name': 'NFL'},
          {'id': 3, 'name': 'Soccer'},
        ]);
      case '/sports/2/categories':
        return jsonResponse(200, [
          {'id': 10, 'name': 'History', 'sportId': 2},
        ]);
      case '/leaderboard?sportId=2&top=100':
        return jsonResponse(200, nfl);
      case '/leaderboard?sportId=3&top=100':
        return jsonResponse(200, soccer);
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

Future<void> openLeaderboard(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Leaderboard'));
  await settleRequest(tester);
  await settleRequest(tester);
}

void main() {
  testWidgets('Shows the top three on the podium and highlights you below', (
    tester,
  ) async {
    usePhoneScreen(tester);
    await launch(
      tester,
      await leaderboardApp(
        nfl: [
          entry(1, 'lebron', 10, 4),
          entry(2, 'steph', 9, 6),
          entry(2, 'kd', 9, 2),
          entry(4, 'kobe24', 7, 3),
          entry(5, 'rookie', 3, 1),
        ],
      ),
    );
    await openLeaderboard(tester);

    expect(find.bySemanticsLabel('Who knows ball?'), findsOneWidget);
    expect(find.bySemanticsLabel('Rank 1, @lebron, best 10'), findsOneWidget);
    // Tied players share a rank.
    expect(find.bySemanticsLabel('Rank 2, @steph, best 9'), findsOneWidget);
    expect(find.bySemanticsLabel('Rank 2, @kd, best 9'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Rank 4, @kobe24, you, best 7, 3 games'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Rank 5, @rookie, best 3, 1 game'),
      findsOneWidget,
    );
    expect(find.text('YOU'), findsOneWidget);
    expect(find.text("You're not on the board yet"), findsNothing);
  });

  testWidgets('Switching sport loads that sport, and an empty board says so', (
    tester,
  ) async {
    usePhoneScreen(tester);
    final app = await leaderboardApp(nfl: [entry(1, 'lebron', 10, 4)]);
    await launch(tester, app);
    await openLeaderboard(tester);
    expect(find.bySemanticsLabel('Rank 1, @lebron, best 10'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Soccer'));
    await settleRequest(tester);

    expect(
      app.adapter.requests.where(
        (r) => r.path == '/leaderboard?sportId=3&top=100',
      ),
      hasLength(1),
    );
    expect(find.text('No scores yet'), findsOneWidget);
    expect(find.bySemanticsLabel('Rank 1, @lebron, best 10'), findsNothing);
  });

  testWidgets("If you haven't played, a nudge takes you to that sport", (
    tester,
  ) async {
    usePhoneScreen(tester);
    await launch(
      tester,
      await leaderboardApp(
        nfl: [entry(1, 'lebron', 10, 4), entry(2, 'steph', 9, 6)],
      ),
    );
    await openLeaderboard(tester);

    expect(find.text("You're not on the board yet"), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Play a round'),
      200,
      // The page itself, not the sideways sport switcher.
      scrollable: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      ),
    );
    await tester.tap(find.text('Play a round'));
    await settleRequest(tester);

    expect(find.text('History'), findsOneWidget, reason: 'Football categories');
  });
}
