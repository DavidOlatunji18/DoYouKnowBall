import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dykb/screens/quiz_screen.dart';
import 'package:dykb/widgets/app_nav_bar.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

/// A logged-in app whose fake API serves a two-question NFL Players round.
/// Question 1's answer is "Tom Brady" (index 1), question 2's is "1967" (index 1).
Future<TestApp> quizApp({List<Map<String, dynamic>> history = const []}) async {
  final answers = <int, int>{};
  const correct = {101: 1, 102: 1};

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
        ]);
      case '/sports/2/categories':
        return jsonResponse(200, [
          {'id': 11, 'name': 'Players', 'sportId': 2},
        ]);
      case '/quiz?categoryId=11':
        answers.clear();
        return jsonResponse(200, {
          'sessionToken': 'round-1',
          'questions': [
            {
              'id': 101,
              'text': 'Which quarterback has the most Super Bowl wins?',
              'options': [
                'Joe Montana',
                'Tom Brady',
                'Terry Bradshaw',
                'Patrick Mahomes',
              ],
            },
            {
              'id': 102,
              'text': 'In which year was Super Bowl I played?',
              'options': ['1969', '1967', '1970', '1966'],
            },
          ],
        });
      case '/quiz/answer':
        final body = request.data as Map<String, dynamic>;
        final id = body['questionId'] as int;
        answers[id] = body['selectedIndex'] as int;
        final score = answers.entries
            .where((e) => correct[e.key] == e.value)
            .length;
        return jsonResponse(200, {
          'correct': correct[id] == answers[id],
          'correctIndex': correct[id],
          'score': score,
          'answered': answers.length,
          'total': 2,
        });
      case '/games':
        final review = [
          for (final id in [101, 102])
            {
              'questionId': id,
              'correctIndex': correct[id],
              'selectedIndex': answers[id] ?? -1,
              'correct': correct[id] == answers[id],
            },
        ];
        return jsonResponse(200, {
          'gameId': 50,
          'score': review.where((r) => r['correct'] == true).length,
          'total': 2,
          'review': review,
        });
      case '/games/history':
        return jsonResponse(200, history);
      case '/leaderboard?sportId=2&top=100':
        return jsonResponse(200, [
          {
            'rank': 1,
            'displayName': 'lebron',
            'bestScore': 10,
            'gamesPlayed': 4,
          },
          {
            'rank': 3,
            'displayName': 'kobe24',
            'bestScore': 1,
            'gamesPlayed': 2,
          },
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

/// From Home, opens Football > Players and waits out the 3-2-1 intro.
Future<void> startRound(WidgetTester tester) async {
  await tester.tap(find.text('Football'));
  await settleRequest(tester);
  await tester.tap(find.text('Players'));
  await settle(tester);
  for (var i = 0; i < 3; i++) {
    await tester.pump(QuizScreen.countdownStep);
  }
  await settle(tester);
}

void main() {
  testWidgets('The intro counts down and shows the sport and category', (
    tester,
  ) async {
    usePhoneScreen(tester);
    await launch(tester, await quizApp());

    await tester.tap(find.text('Football'));
    await settleRequest(tester);
    await tester.tap(find.text('Players'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('FOOTBALL · PLAYERS'), findsOneWidget);
    expect(find.bySemanticsLabel('Do you know ball?'), findsOneWidget);
    expect(find.bySemanticsLabel('Starting in 3'), findsOneWidget);

    await tester.pump(QuizScreen.countdownStep);
    expect(find.bySemanticsLabel('Starting in 2'), findsOneWidget);

    await tester.pump(QuizScreen.countdownStep * 2);
    await settle(tester);
    expect(
      find.text('Which quarterback has the most Super Bowl wins?'),
      findsOneWidget,
    );
    expect(find.text('QUESTION 1 OF 2'), findsOneWidget);
    expect(find.byType(AppNavBar), findsNothing, reason: 'full-screen');
  });

  testWidgets(
    'A full round: instant feedback, then results with the recap, best and rank',
    (tester) async {
      usePhoneScreen(tester);
      final app = await quizApp(
        history: [
          {
            'gameId': 50,
            'sportName': 'NFL',
            'categoryName': 'Players',
            'score': 1,
            'total': 2,
            'playedAt': '2026-10-27T12:00:00Z',
          },
          {
            'gameId': 40,
            'sportName': 'NFL',
            'categoryName': 'Players',
            'score': 0,
            'total': 2,
            'playedAt': '2026-10-26T12:00:00Z',
          },
        ],
      );
      await launch(tester, app);
      await startRound(tester);

      // Right answer: green, "Nice!", score goes up.
      await tester.tap(find.text('Tom Brady'));
      await settle(tester);
      expect(find.text('Nice!'), findsOneWidget);
      expect(find.text('You know ball.'), findsOneWidget);
      expect(find.bySemanticsLabel('Score 1'), findsOneWidget);
      expect(
        find.bySemanticsLabel('B. Tom Brady, correct answer'),
        findsOneWidget,
      );

      final sent = app.adapter.requestTo('/quiz/answer').data as Map;
      expect(sent, {
        'sessionToken': 'round-1',
        'questionId': 101,
        'selectedIndex': 1,
      });

      // It moves on by itself.
      await tester.pump(QuizScreen.rightPause);
      await settle(tester);
      expect(find.text('QUESTION 2 OF 2'), findsOneWidget);

      // Wrong answer: "Not quite / Lock in twin", and the right one is shown.
      await tester.tap(find.text('1969'));
      await settle(tester);
      expect(find.text('Not quite'), findsOneWidget);
      expect(find.text('Lock in twin'), findsOneWidget);
      expect(
        find.bySemanticsLabel('A. 1969, your answer, wrong'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('B. 1967, correct answer'), findsOneWidget);
      expect(find.bySemanticsLabel('Score 1'), findsOneWidget);

      // Last question: the bar says Results.
      await tester.tap(find.text('Results'));
      await settleRequest(tester);
      await tester.pump(const Duration(seconds: 2)); // ring fills

      expect(app.adapter.requestTo('/games').data, {'sessionToken': 'round-1'});
      expect(find.bySemanticsLabel('1 out of 2'), findsOneWidget);
      expect(find.text('You know some ball.'), findsOneWidget);
      // Best excludes this game (id 50): before it, the best was 0, so 1 is new.
      expect(find.bySemanticsLabel('Your best: 1/2, new best'), findsOneWidget);
      expect(find.bySemanticsLabel('Streak: 1'), findsOneWidget);
      expect(find.bySemanticsLabel('Rank: #3'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('YOUR ANSWERS'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        find.bySemanticsLabel(
          RegExp(r'^Right\. Which quarterback .* Tom Brady$'),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Missed. In which year was Super Bowl I played? You picked 1969. Answer: 1967',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('Quitting asks first; Keep playing stays, Leave goes back', (
    tester,
  ) async {
    usePhoneScreen(tester);
    await launch(tester, await quizApp());
    await startRound(tester);

    await tester.tap(find.bySemanticsLabel('Quit'));
    await settle(tester);
    expect(find.text('Leave this round?'), findsOneWidget);

    await tester.tap(find.text('Keep playing'));
    await settle(tester);
    expect(find.text('Leave this round?'), findsNothing);
    expect(find.text('QUESTION 1 OF 2'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Quit'));
    await settle(tester);
    await tester.tap(find.text('Leave round'));
    await settle(tester);
    expect(find.text('Players'), findsOneWidget, reason: 'back on categories');
    expect(find.byType(QuizScreen), findsNothing);
  });

  testWidgets('If the questions fail to load, Try again starts over', (
    tester,
  ) async {
    usePhoneScreen(tester);
    var fail = true;
    final app = await quizApp();
    final handler = app.adapter.handler;
    final flaky = TestApp((request) {
      if (request.path.startsWith('/quiz?') && fail) {
        fail = false;
        throw DioException.connectionError(
          requestOptions: request,
          reason: 'offline',
        );
      }
      return handler(request);
    });
    await flaky.store.write('auth_token', 'saved-token');
    await flaky.store.write(
      'auth_user',
      jsonEncode({'id': 1, 'email': 'k@b.co', 'displayName': 'kobe24'}),
    );
    await launch(tester, flaky);
    await startRound(tester);

    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );
    await tester.tap(find.text('Try again'));
    await settle(tester);
    for (var i = 0; i < 3; i++) {
      await tester.pump(QuizScreen.countdownStep);
    }
    await settle(tester);
    expect(find.text('QUESTION 1 OF 2'), findsOneWidget);
  });
}
