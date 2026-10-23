import 'package:dykb/screens/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('Welcome animates in and shows every element', (tester) async {
    usePhoneScreen(tester);
    await launch(tester, TestApp((_) => jsonResponse(500, {})));

    // Mid-entrance: the headline is already on screen.
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(WelcomeScreen.headline), findsOneWidget);

    // After the entrance finishes (the idle bob keeps running, so no pumpAndSettle).
    await tester.pump(const Duration(seconds: 4));
    expect(
      find.text(WelcomeScreen.tagline, findRichText: true),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Soccer, football, basketball, baseball and hockey',
      ),
      findsOneWidget,
    );
    expect(find.byType(Image), findsNWidgets(1 + WelcomeScreen.balls.length));
    expect(find.text('Sign up'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });

  testWidgets('Sign up and Log in open the auth screen in the right mode', (
    tester,
  ) async {
    usePhoneScreen(tester);
    await launch(tester, TestApp((_) => jsonResponse(500, {})));
    await tester.pump(const Duration(seconds: 4));

    await tester.tap(find.text('Sign up'));
    await settle(tester);
    expect(find.text('USERNAME'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Back'));
    await settle(tester);
    await tester.tap(find.text('Log in'));
    await settle(tester);
    expect(find.text('USERNAME'), findsNothing);
    expect(find.widgetWithText(Center, 'Log in'), findsWidgets);
  });

  testWidgets('With reduce motion on, everything is visible immediately', (
    tester,
  ) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: WelcomeScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text(WelcomeScreen.tagline, findRichText: true),
      findsOneWidget,
    );
    final opacities = tester
        .widgetList<Opacity>(find.byType(Opacity))
        .map((o) => o.opacity);
    expect(opacities, everyElement(1.0));
  });
}
