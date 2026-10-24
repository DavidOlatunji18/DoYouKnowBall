import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dykb/screens/splash_screen.dart';
import 'package:dykb/screens/welcome_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

Future<TestApp> appWithSavedLogin(
  ResponseBody Function(RequestOptions) handler,
) async {
  final app = TestApp(handler);
  await app.store.write('auth_token', 'saved-token');
  await app.store.write(
    'auth_user',
    jsonEncode({'id': 1, 'email': 'a@b.co', 'displayName': 'old_name'}),
  );
  return app;
}

void main() {
  testWidgets('The splash shows the loader, then hands over to Welcome', (
    tester,
  ) async {
    usePhoneScreen(tester);
    final app = TestApp((_) => jsonResponse(500, {}));
    await tester.pumpWidget(app.build());
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(SpiralLoader), findsOneWidget);
    expect(
      app.adapter.requests,
      isEmpty,
      reason: 'no saved login, so nothing to check',
    );

    await tester.pump(SplashScreen.minimumDuration);
    await settleRequest(tester);
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });

  testWidgets('Android draws its own artwork, matching its launch screen', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    usePhoneScreen(tester);
    await tester.pumpWidget(TestApp((_) => jsonResponse(500, {})).build());
    await tester.pump();

    final images = {
      for (final image in tester.widgetList<Image>(find.byType(Image)))
        (image.image as AssetImage).assetName: Size(
          image.width!,
          image.height!,
        ),
    };
    expect(images['assets/branding/splash-android.png'], const Size(288, 288));
    expect(
      images['assets/branding/splash-wordmark-android.png'],
      const Size(200, 80),
    );
    expect(
      find.byType(Opacity),
      findsNothing,
      reason: 'the text is there from the start, not faded in',
    );

    await tester.pump(SplashScreen.minimumDuration);
    await settleRequest(tester);
    expect(find.byType(WelcomeScreen), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('A valid saved login goes to Home with the latest username', (
    tester,
  ) async {
    usePhoneScreen(tester);
    final app = await appWithSavedLogin(
      (_) => jsonResponse(200, {
        'id': 1,
        'email': 'a@b.co',
        'displayName': 'new_name',
      }),
    );

    await launch(tester, app);

    expect(app.adapter.requestTo('/me'), isNotNull);
    expect(
      app.adapter.requestTo('/me').headers['Authorization'],
      'Bearer saved-token',
    );
    expect(find.bySemanticsLabel('Welcome @new_name'), findsOneWidget);
    expect(await app.store.read('auth_user'), contains('new_name'));
  });

  testWidgets('An expired login is cleared and the player sees Welcome', (
    tester,
  ) async {
    usePhoneScreen(tester);
    final app = await appWithSavedLogin(
      (_) => jsonResponse(401, {'error': 'Please log in to continue.'}),
    );

    await launch(tester, app);

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(app.session.isLoggedIn, isFalse);
    expect(await app.store.read('auth_token'), isNull);
  });

  testWidgets("If the API can't be reached, the saved login is kept", (
    tester,
  ) async {
    usePhoneScreen(tester);
    final app = await appWithSavedLogin(
      (request) => throw DioException.connectionError(
        requestOptions: request,
        reason: 'offline',
      ),
    );

    await launch(tester, app);

    expect(app.session.isLoggedIn, isTrue);
    expect(find.bySemanticsLabel('Welcome @old_name'), findsOneWidget);
  });
}
