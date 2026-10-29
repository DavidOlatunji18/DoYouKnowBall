import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

Map<String, dynamic> entry(
  int rank,
  String name,
  int xp, {
  int level = 23,
  String rankName = 'Real Fan',
  int? best,
  int games = 3,
}) => {
  'rank': rank,
  'displayName': name,
  'xp': xp,
  'level': level,
  'rankName': rankName,
  'bestScore': best,
  'gamesPlayed': games,
};

/// A logged-in app (as @kobe24) whose fake API serves the global board and one
/// board per sport id: NFL is sport 2, Soccer is sport 3.
Future<TestApp> leaderboardApp({
  Map<String, dynamic> global = const {'top': [], 'me': null},
  Map<String, dynamic> nfl = const {'top': [], 'me': null},
  Map<String, dynamic> soccer = const {'top': [], 'me': null},
}) async {
  final app = TestApp((RequestOptions request) {
    switch (request.path) {
      case '/me':
        return jsonResponse(200, {
          'id': 1,
          'email': 'k@b.co',
          'displayName': 'kobe24',
        });
      case '/me/progress':
        return jsonResponse(200, {
          'xp': 6640,
          'level': 23,
          'levelXp': 640,
          'levelXpNeeded': 1000,
          'rank': 'Real Fan',
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
      case '/leaderboard':
        return jsonResponse(200, global);
      case '/leaderboard?sportId=2':
        return jsonResponse(200, nfl);
      case '/leaderboard?sportId=3':
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

/// The page itself, not the sideways tabs.
final pageScroller = find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
);

void main() {
  testWidgets('Global shows the top players by XP with level and rank', (
    tester,
  ) async {
    usePhoneScreen(tester);
    final me = entry(4, 'kobe24', 6640);
    final app = await leaderboardApp(
      global: {
        'top': [
          entry(1, 'lebron', 48210, level: 104, rankName: 'YKB'),
          entry(2, 'steph', 39560, level: 88, rankName: 'GOAT'),
          entry(2, 'kd', 39560, level: 88, rankName: 'GOAT'),
          me,
        ],
        'me': me,
      },
    );
    await launch(tester, app);
    await openLeaderboard(tester);

    expect(app.adapter.requestTo('/leaderboard').path, '/leaderboard');
    expect(find.text('GLOBAL'), findsNothing, reason: 'part of a rich label');
    expect(
      find.bySemanticsLabel('Rank 1, @lebron, level 104 YKB, 48,210 XP'),
      findsOneWidget,
    );
    // Tied players share a rank.
    expect(
      find.bySemanticsLabel('Rank 2, @steph, level 88 GOAT, 39,560 XP'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Rank 2, @kd, level 88 GOAT, 39,560 XP'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Rank 4, @kobe24, you, level 23 Real Fan, 6,640 XP',
      ),
      findsOneWidget,
      reason: "you're in the list, so there's no pinned row",
    );
    expect(find.text("You're not on the board yet"), findsNothing);
  });

  testWidgets("Below the top 10, your row is pinned under the list", (
    tester,
  ) async {
    usePhoneScreen(tester);
    await launch(
      tester,
      await leaderboardApp(
        global: {
          'top': [
            for (var i = 1; i <= 10; i++) entry(i, 'pro$i', 50000 - i * 1000),
          ],
          'me': entry(23, 'kobe24', 6640),
        },
      ),
    );
    await openLeaderboard(tester);

    await tester.scrollUntilVisible(
      find.textContaining('kobe24'),
      200,
      scrollable: pageScroller,
    );
    expect(
      find.bySemanticsLabel(
        'Rank 23, @kobe24, you, level 23 Real Fan, 6,640 XP',
      ),
      findsOneWidget,
    );
  });

  testWidgets('A sport tab ranks by XP in that sport and shows best scores', (
    tester,
  ) async {
    usePhoneScreen(tester);
    final app = await leaderboardApp(
      global: {
        'top': [entry(1, 'lebron', 48210, level: 104, rankName: 'YKB')],
        'me': null,
      },
      nfl: {
        'top': [
          entry(1, 'mahomes15', 9840, level: 79, rankName: 'GOAT', best: 10),
        ],
        'me': null,
      },
    );
    await launch(tester, app);
    await openLeaderboard(tester);

    await tester.tap(find.bySemanticsLabel('Football'));
    await settleRequest(tester);

    expect(app.adapter.requestTo('/leaderboard?sportId=2'), isNotNull);
    expect(
      find.bySemanticsLabel(
        'Rank 1, @mahomes15, level 79 GOAT, 9,840 XP, best 10 out of 10',
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('@lebron')), findsNothing);
  });

  testWidgets('An empty sport says so', (tester) async {
    usePhoneScreen(tester);
    await launch(tester, await leaderboardApp());
    await openLeaderboard(tester);

    await tester.tap(find.bySemanticsLabel('Soccer'));
    await settleRequest(tester);

    expect(find.text('No scores yet'), findsOneWidget);
  });

  testWidgets("If you haven't played, a nudge takes you to that sport", (
    tester,
  ) async {
    usePhoneScreen(tester);
    await launch(
      tester,
      await leaderboardApp(
        nfl: {
          'top': [entry(1, 'mahomes15', 9840, best: 10)],
          'me': null,
        },
      ),
    );
    await openLeaderboard(tester);
    await tester.tap(find.bySemanticsLabel('Football'));
    await settleRequest(tester);

    expect(find.text("You're not on the board yet"), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Play a round'),
      200,
      scrollable: pageScroller,
    );
    await tester.tap(find.text('Play a round'));
    await settleRequest(tester);

    expect(find.text('History'), findsOneWidget, reason: 'Football categories');
  });
}
