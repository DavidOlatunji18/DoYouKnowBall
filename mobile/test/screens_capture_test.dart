// Renders the main screens to PNGs with the app's real fonts, for reviewing design
// changes side by side. Skipped in normal test runs; to capture:
//
//   CAPTURE_DIR=/some/folder flutter test test/screens_capture_test.dart
//
// Screens are drawn at iPhone 16 size (393x852 points). Emoji don't render here.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:dykb/screens/quiz_screen.dart';
import 'package:dykb/screens/splash_screen.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/fakes.dart';

final _outDir = Platform.environment['CAPTURE_DIR'];

Map<String, dynamic> _entry(
  int rank,
  String name,
  int xp,
  int level,
  String r, [
  int? best,
]) => {
  'rank': rank,
  'displayName': name,
  'xp': xp,
  'level': level,
  'rankName': r,
  'bestScore': best,
  'gamesPlayed': 12,
};

ResponseBody _api(RequestOptions request) {
  final progress = {
    'xp': 18640,
    'level': 21,
    'levelXp': 640,
    'levelXpNeeded': 1000,
    'rank': 'Real Fan',
  };
  switch (request.path) {
    case '/me':
      return jsonResponse(200, {
        'id': 1,
        'email': 'kobe@dykb.app',
        'displayName': 'kobe24',
      });
    case '/me/progress':
      return jsonResponse(200, progress);
    case '/sports':
      return jsonResponse(200, [
        {'id': 1, 'name': 'MLB'},
        {'id': 2, 'name': 'NBA'},
        {'id': 3, 'name': 'NFL'},
        {'id': 4, 'name': 'NHL'},
        {'id': 5, 'name': 'Soccer'},
      ]);
    case '/sports/3/categories':
      return jsonResponse(200, [
        {'id': 10, 'name': 'History', 'sportId': 3},
        {'id': 11, 'name': 'Players', 'sportId': 3},
        {'id': 12, 'name': 'Records and Stats', 'sportId': 3},
      ]);
    case '/games/history':
      return jsonResponse(200, [
        for (var i = 0; i < 6; i++)
          {
            'gameId': 100 - i,
            'sportName': ['NFL', 'Soccer', 'NBA'][i % 3],
            'categoryName': ['Players', 'Internationals', 'History'][i % 3],
            'score': [9, 6, 4, 10, 7, 8][i],
            'total': 10,
            'playedAt': '2026-10-2${8 - i}T18:00:00Z',
          },
      ]);
    case '/leaderboard':
      return jsonResponse(200, {
        'top': [
          _entry(1, 'lebron', 98210, 99, 'GOAT'),
          _entry(2, 'steph', 79560, 80, 'GOAT'),
          _entry(3, 'mahomes15', 64020, 65, 'Unc'),
          _entry(4, 'messi_fan', 44890, 45, 'Certified'),
          _entry(5, 'ovi8', 30115, 31, 'Certified'),
          _entry(6, 'kobe24', 18640, 21, 'Real Fan'),
          _entry(7, 'rookie', 3200, 5, 'Benchwarmer'),
        ],
        'me': _entry(6, 'kobe24', 18640, 21, 'Real Fan'),
      });
    case '/quiz?categoryId=11':
      return jsonResponse(200, {
        'sessionToken': 'round',
        'questions': [
          {
            'id': 1,
            'text': 'Which quarterback has the most Super Bowl wins?',
            'options': [
              'Joe Montana',
              'Tom Brady',
              'Terry Bradshaw',
              'Patrick Mahomes',
            ],
          },
          {
            'id': 2,
            'text': 'In which year was Super Bowl I played?',
            'options': ['1969', '1967', '1970', '1966'],
          },
        ],
      });
    case '/quiz/answer':
      final body = request.data as Map<String, dynamic>;
      final correct = body['questionId'] == 1 ? 1 : 1;
      return jsonResponse(200, {
        'correct': body['selectedIndex'] == correct,
        'correctIndex': correct,
        'score': 1,
        'answered': 1,
        'total': 2,
      });
    case '/games':
      return jsonResponse(200, {
        'gameId': 200,
        'score': 1,
        'total': 2,
        'review': [
          {
            'questionId': 1,
            'correctIndex': 1,
            'selectedIndex': 1,
            'correct': true,
          },
          {
            'questionId': 2,
            'correctIndex': 1,
            'selectedIndex': 0,
            'correct': false,
          },
        ],
        'xp': {'correct': 10, 'round': 20, 'perfect': 0, 'total': 30},
        'before': progress,
        'after': {...progress, 'xp': 18670, 'levelXp': 670},
      });
    case '/leaderboard?sportId=3':
      return jsonResponse(200, {'top': [], 'me': null});
  }
  return jsonResponse(404, {'error': 'Not found'});
}

Future<void> _loadFonts() async {
  Future<void> load(String family, Future<ByteData> bytes) =>
      (FontLoader(family)..addFont(bytes)).load();
  await load('Montserrat', rootBundle.load('assets/fonts/Montserrat.ttf'));
  await load('Fredoka', rootBundle.load('assets/fonts/Fredoka.ttf'));
  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ??
      '${Platform.environment['HOME']}/flutter';
  final icons = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  await load(
    'MaterialIcons',
    Future.value(ByteData.sublistView(icons.readAsBytesSync())),
  );
}

final _boundary = GlobalKey();

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 1600)); // let entrances finish
  // Images decode asynchronously; load them for real before drawing.
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
  });
  await tester.pump();
  await tester.pump();
  final render =
      _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await render.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_outDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('capture screens', (tester) async {
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = const Size(1179, 2556); // iPhone 16
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final app = TestApp(_api);
    await app.store.write('auth_token', 'saved-token');
    await app.store.write(
      'auth_user',
      jsonEncode({'id': 1, 'email': 'kobe@dykb.app', 'displayName': 'kobe24'}),
    );
    await tester.pumpWidget(
      RepaintBoundary(key: _boundary, child: app.build()),
    );
    await tester.pump(SplashScreen.minimumDuration);
    await settleRequest(tester);
    await settleRequest(tester);
    await _shot(tester, '1-home');

    await tester.tap(find.text('Football'));
    await settleRequest(tester);
    await _shot(tester, '2-categories');

    await tester.tap(find.text('Players'));
    await settle(tester);
    for (var i = 0; i < 3; i++) {
      await tester.pump(QuizScreen.countdownStep);
    }
    await settle(tester);
    await _shot(tester, '3-question');

    await tester.tap(find.text('Joe Montana'));
    await settle(tester);
    await _shot(tester, '4-wrong-answer');
    await tester.pump(QuizScreen.wrongPause);
    await settle(tester);
    await tester.tap(find.text('1967'));
    await settle(tester);
    await tester.tap(find.text('Results'));
    await settleRequest(tester);
    await settleRequest(tester);
    await _shot(tester, '5-results');

    GoRouter.of(tester.element(find.byType(QuizScreen))).go('/leaderboard');
    await settleRequest(tester);
    await settleRequest(tester);
    await _shot(tester, '6-leaderboard');

    await tester.tap(find.bySemanticsLabel('Profile'));
    await settleRequest(tester);
    await settleRequest(tester);
    await _shot(tester, '7-profile');
  }, skip: _outDir == null);
}
