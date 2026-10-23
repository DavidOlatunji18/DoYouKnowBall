import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dykb/api/api_client.dart';
import 'package:dykb/auth/session.dart';
import 'package:dykb/main.dart';
import 'package:dykb/screens/splash_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the network: every request goes to [handler] instead of a server.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions request) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(int status, Object body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

Map<String, dynamic> authJson({String displayName = 'kobe'}) => {
  'token': 'jwt-token',
  'user': {'id': 7, 'email': 'kobe@example.com', 'displayName': displayName},
};

/// The whole app wired to an in-memory session and a fake API.
class TestApp {
  TestApp(ResponseBody Function(RequestOptions request) handler)
    : adapter = FakeAdapter(handler) {
    session = Session(store);
    api = ApiClient(
      baseUrl: 'http://api.test',
      token: () => session.token,
      onUnauthorized: session.signOut,
      dio: Dio()..httpClientAdapter = adapter,
    );
  }

  final FakeAdapter adapter;
  final store = MemoryTokenStore();
  late final Session session;
  late final ApiClient api;

  Widget build() => DykbApp(session: session, api: api);
}

/// Runs a test on an iPhone-sized screen instead of the default 800x600 window.
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Lets the router handle a navigation, then finishes the page transition.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Waits out a request to the fake API, then the navigation it triggers.
Future<void> settleRequest(WidgetTester tester) async {
  await settle(tester);
  await settle(tester);
}

/// Starts the app and waits for the splash screen to hand over to Welcome or Home.
Future<void> launch(WidgetTester tester, TestApp app) async {
  await tester.pumpWidget(app.build());
  await tester.pump(SplashScreen.minimumDuration);
  await settleRequest(tester);
}
