import 'dart:convert';

import 'package:dykb/auth/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

Future<void> openSignUp(WidgetTester tester, TestApp app) async {
  usePhoneScreen(tester);
  await launch(tester, app);
  await tester.pump(const Duration(seconds: 4));
  await tester.tap(find.text('Sign up'));
  await settle(tester);
}

Finder field(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
  matching: find.byType(TextField),
);

void main() {
  testWidgets('Invalid input shows field errors without calling the API', (
    tester,
  ) async {
    final app = TestApp((_) => jsonResponse(200, authJson()));
    await openSignUp(tester, app);

    await tester.enterText(field('USERNAME'), 'k.');
    await tester.enterText(field('EMAIL'), 'not-an-email');
    await tester.enterText(field('PASSWORD'), 'short');
    await tester.tap(find.text('Create account'));
    await tester.pump();

    expect(find.text('Usernames must be 3-30 characters.'), findsOneWidget);
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Use at least 8 characters.'), findsOneWidget);
    expect(app.adapter.requests, isEmpty);
  });

  testWidgets('Signing up saves the session and lands on Home', (tester) async {
    final app = TestApp(
      (_) => jsonResponse(200, authJson(displayName: 'kobe')),
    );
    await openSignUp(tester, app);

    await tester.enterText(field('USERNAME'), '  Kobe 24!');
    await tester.enterText(field('EMAIL'), 'kobe@example.com');
    await tester.enterText(field('PASSWORD'), 'mamba-mentality');
    await tester.tap(find.text('Create account'));
    await settleRequest(tester);

    final request = app.adapter.requests.single;
    expect(request.path, '/auth/register');
    expect(request.data, {
      'email': 'kobe@example.com',
      'password': 'mamba-mentality',
      'displayName': 'kobe24',
    });
    expect(app.session.isLoggedIn, isTrue);
    expect(await app.store.read('auth_token'), 'jwt-token');
    expect(find.text('@kobe.'), findsOneWidget); // "You're in, @kobe." on Home
  });

  testWidgets('A guessable password is flagged live and blocked on submit', (
    tester,
  ) async {
    final app = TestApp((_) => jsonResponse(200, authJson()));
    await openSignUp(tester, app);

    await tester.enterText(field('USERNAME'), 'kobe24');
    await tester.enterText(field('EMAIL'), 'kobe@example.com');
    await tester.enterText(field('PASSWORD'), 'password123');
    await tester.pump();
    expect(
      find.text('That password is too common. Try something harder to guess.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Create account'));
    await tester.pump();
    expect(app.adapter.requests, isEmpty);

    await tester.enterText(field('PASSWORD'), 'hoops-and-dreams');
    await tester.pump();
    expect(find.text('Hard to guess'), findsOneWidget);
  });

  testWidgets('A server error is shown in the banner', (tester) async {
    final app = TestApp(
      (_) => jsonResponse(409, {
        'error': 'An account with that email already exists.',
      }),
    );
    await openSignUp(tester, app);

    await tester.enterText(field('USERNAME'), 'Kobe');
    await tester.enterText(field('EMAIL'), 'kobe@example.com');
    await tester.enterText(field('PASSWORD'), 'mamba-mentality');
    await tester.tap(find.text('Create account'));
    await settleRequest(tester);

    expect(
      find.text('An account with that email already exists.'),
      findsOneWidget,
    );
    expect(app.session.isLoggedIn, isFalse);
  });

  testWidgets(
    'The toggle switches to Log in and logs in with email and password only',
    (tester) async {
      final app = TestApp((_) => jsonResponse(200, authJson()));
      await openSignUp(tester, app);

      await tester.tap(find.text('Log in').first);
      await settle(tester);
      expect(find.text('USERNAME'), findsNothing);

      await tester.enterText(field('EMAIL OR USERNAME'), 'kobe24');
      await tester.enterText(field('PASSWORD'), 'mamba-mentality');
      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Log in' &&
              w.properties.button == true,
        ),
      );
      await settle(tester);

      expect(app.adapter.requests.single.path, '/auth/login');
      expect(app.adapter.requests.single.data, {
        'emailOrUsername': 'kobe24',
        'password': 'mamba-mentality',
      });
      expect(app.session.isLoggedIn, isTrue);
    },
  );

  testWidgets('A saved session skips Welcome and opens Home', (tester) async {
    usePhoneScreen(tester);
    final app = TestApp((_) => jsonResponse(500, {}));
    await app.store.write('auth_token', 'saved-token');
    await app.store.write(
      'auth_user',
      jsonEncode({'id': 1, 'email': 'a@b.co', 'displayName': 'returning'}),
    );
    await app.session.restore();

    await launch(tester, app);
    await settle(tester);

    expect(find.text('@returning.'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);

    await tester.tap(find.text('Log out'));
    await settle(tester);
    expect(app.session.isLoggedIn, isFalse);
    expect(await app.store.read('auth_token'), isNull);
  });

  test('Session.restore ignores a half-written session', () async {
    final store = MemoryTokenStore()
      ..values['auth_token'] = 'token-without-user';
    final session = Session(store);
    await session.restore();
    expect(session.isLoggedIn, isFalse);
  });
}
