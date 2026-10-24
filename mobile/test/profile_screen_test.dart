import 'package:dykb/game_events.dart';
import 'package:dykb/screens/profile_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'home_screen_test.dart' show loggedInApp;
import 'support/fakes.dart';

Map<String, dynamic> game(
  int id,
  String sport,
  String category,
  int score, {
  String playedAt = '2026-10-23T18:00:00Z',
}) => {
  'gameId': id,
  'sportName': sport,
  'categoryName': category,
  'score': score,
  'total': 10,
  'playedAt': playedAt,
};

Future<void> openProfile(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Profile'));
  await settleRequest(tester);
}

void main() {
  testWidgets('Profile shows stats, best per sport, and recent games', (
    tester,
  ) async {
    usePhoneScreen(tester);
    await launch(
      tester,
      await loggedInApp(
        history: [
          game(3, 'NFL', 'Players', 9),
          game(2, 'Soccer', 'Internationals', 4),
          game(1, 'NFL', 'History', 5),
        ],
      ),
    );
    await openProfile(tester);

    expect(find.text('@kobe24'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // games
    expect(find.text('60%'), findsOneWidget); // 18 of 30 correct
    expect(
      find.text('9/10'),
      findsWidgets,
    ); // best overall, best for football, and in recent games
    expect(find.text('Best round: Players'), findsOneWidget); // football's best
    expect(find.text('Best round: Internationals'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('History'), 300);
    expect(find.text('Players'), findsOneWidget);
    expect(find.text('Internationals'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
  });

  testWidgets('With no games yet, Profile invites you to play', (tester) async {
    usePhoneScreen(tester);
    await launch(tester, await loggedInApp());
    await openProfile(tester);

    expect(find.textContaining('No games yet'), findsOneWidget);
    await tester.tap(find.text('Play a round'));
    await settleRequest(tester);
    expect(find.bySemanticsLabel('Welcome @kobe24'), findsOneWidget);
  });

  testWidgets('Finishing a round reloads Profile', (tester) async {
    usePhoneScreen(tester);
    final app = await loggedInApp();
    await launch(tester, app);
    await openProfile(tester);
    final before = app.adapter.requests
        .where((r) => r.path == '/games/history')
        .length;

    tester
        .element(find.byType(ProfileScreen))
        .read<GameEvents>()
        .gameFinished();
    await settleRequest(tester);

    expect(
      app.adapter.requests.where((r) => r.path == '/games/history').length,
      before + 1,
    );
  });
}
