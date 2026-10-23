import 'package:dio/dio.dart';
import 'package:dykb/api/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  ApiClient client(
    FakeAdapter adapter, {
    String? token,
    void Function()? onUnauthorized,
  }) => ApiClient(
    baseUrl: 'http://api.test',
    token: () => token,
    onUnauthorized: onUnauthorized,
    dio: Dio()..httpClientAdapter = adapter,
  );

  test('login parses the token and user', () async {
    final adapter = FakeAdapter(
      (_) => jsonResponse(200, authJson(displayName: 'LeBron')),
    );

    final result = await client(
      adapter,
    ).login(emailOrUsername: 'a@b.co', password: 'password123');

    expect(result.token, 'jwt-token');
    expect(result.user.displayName, 'LeBron');
    expect(adapter.requests.single.path, '/auth/login');
  });

  test('the saved token is sent as a bearer header', () async {
    final adapter = FakeAdapter((_) => jsonResponse(200, authJson()));

    await client(
      adapter,
      token: 'abc',
    ).login(emailOrUsername: 'a@b.co', password: 'password123');

    expect(adapter.requests.single.headers['Authorization'], 'Bearer abc');
  });

  test('API errors surface the server message', () async {
    final adapter = FakeAdapter(
      (_) => jsonResponse(401, {'error': 'Incorrect email or password.'}),
    );
    var unauthorizedCalls = 0;

    final call = client(
      adapter,
      onUnauthorized: () => unauthorizedCalls++,
    ).login(emailOrUsername: 'a@b.co', password: 'nope');

    await expectLater(
      call,
      throwsA(
        isA<ApiError>().having(
          (e) => e.message,
          'message',
          'Incorrect email or password.',
        ),
      ),
    );
    expect(
      unauthorizedCalls,
      0,
      reason: 'a failed login is not an expired session',
    );
  });

  test('unreadable error bodies fall back to a friendly message', () async {
    final adapter = FakeAdapter(
      (_) => ResponseBody.fromString('<html>Bad Gateway</html>', 502),
    );

    final call = client(
      adapter,
    ).login(emailOrUsername: 'a@b.co', password: 'x');

    await expectLater(
      call,
      throwsA(
        isA<ApiError>().having((e) => e.message, 'message', ApiError.unknown),
      ),
    );
  });

  test('network failures become a connection message', () async {
    final adapter = FakeAdapter(
      (request) => throw DioException.connectionError(
        requestOptions: request,
        reason: 'refused',
      ),
    );

    final call = client(
      adapter,
    ).login(emailOrUsername: 'a@b.co', password: 'x');

    await expectLater(
      call,
      throwsA(
        isA<ApiError>().having((e) => e.message, 'message', ApiError.network),
      ),
    );
  });
}
