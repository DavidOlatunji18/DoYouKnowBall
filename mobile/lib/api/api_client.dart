import 'dart:io';

import 'package:dio/dio.dart';

/// A failed API call, with a message that's safe to show to the player.
class ApiError implements Exception {
  const ApiError(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  static const network =
      "Can't reach the server. Check your connection and try again.";
  static const unknown = 'Something went wrong. Please try again.';

  @override
  String toString() => 'ApiError($statusCode): $message';
}

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as int,
    email: json['email'] as String,
    displayName: json['displayName'] as String,
  );

  final int id;
  final String email;
  final String displayName;

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
  };
}

class AuthResult {
  const AuthResult({required this.token, required this.user});

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
    token: json['token'] as String,
    user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
  );

  final String token;
  final AppUser user;
}

class Sport {
  const Sport({required this.id, required this.name});

  factory Sport.fromJson(Map<String, dynamic> json) =>
      Sport(id: json['id'] as int, name: json['name'] as String);

  final int id;
  final String name;
}

class SportCategory {
  const SportCategory({
    required this.id,
    required this.name,
    required this.sportId,
  });

  factory SportCategory.fromJson(Map<String, dynamic> json) => SportCategory(
    id: json['id'] as int,
    name: json['name'] as String,
    sportId: json['sportId'] as int,
  );

  final int id;
  final String name;
  final int sportId;
}

/// One finished round, as listed in the player's history.
class GameRecord {
  const GameRecord({
    required this.gameId,
    required this.sportName,
    required this.categoryName,
    required this.score,
    required this.total,
    required this.playedAt,
  });

  factory GameRecord.fromJson(Map<String, dynamic> json) => GameRecord(
    gameId: json['gameId'] as int,
    sportName: json['sportName'] as String,
    categoryName: json['categoryName'] as String,
    score: json['score'] as int,
    total: json['total'] as int,
    playedAt: DateTime.parse(json['playedAt'] as String).toLocal(),
  );

  final int gameId;
  final String sportName;
  final String categoryName;
  final int score;
  final int total;
  final DateTime playedAt;
}

/// Talks to the Do You Know Ball? API. Attaches the saved JWT to every request
/// and calls [onUnauthorized] when the server rejects it (expired or revoked),
/// so the app can send the player back to log in.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required String? Function() token,
    void Function()? onUnauthorized,
    Dio? dio,
  }) : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = baseUrl
      ..connectTimeout = const Duration(seconds: 10)
      ..receiveTimeout = const Duration(seconds: 15)
      ..contentType = Headers.jsonContentType;

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final jwt = token();
          if (jwt != null) options.headers['Authorization'] = 'Bearer $jwt';
          handler.next(options);
        },
        onError: (error, handler) {
          // A 401 from /auth/* just means bad credentials; anywhere else the session is no good.
          final isAuthCall = error.requestOptions.path.startsWith('/auth/');
          if (error.response?.statusCode == 401 && !isAuthCall) {
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;

  Future<AuthResult> register({
    required String email,
    required String password,
    required String displayName,
  }) => _post('/auth/register', {
    'email': email,
    'password': password,
    'displayName': displayName,
  }, AuthResult.fromJson);

  /// [emailOrUsername] accepts either; the API works out which it is.
  Future<AuthResult> login({
    required String emailOrUsername,
    required String password,
  }) => _post('/auth/login', {
    'emailOrUsername': emailOrUsername,
    'password': password,
  }, AuthResult.fromJson);

  /// The account behind the saved token; a 401 means the login is no longer valid.
  Future<AppUser> me() async =>
      AppUser.fromJson(await _get<Map<String, dynamic>>('/me'));

  Future<List<Sport>> sports() async => (await _get<List<dynamic>>(
    '/sports',
  )).map((j) => Sport.fromJson(j as Map<String, dynamic>)).toList();

  Future<List<SportCategory>> categories(int sportId) async =>
      (await _get<List<dynamic>>(
        '/sports/$sportId/categories',
      )).map((j) => SportCategory.fromJson(j as Map<String, dynamic>)).toList();

  /// The player's most recent rounds, newest first (the API returns up to 50).
  Future<List<GameRecord>> history() async => (await _get<List<dynamic>>(
    '/games/history',
  )).map((j) => GameRecord.fromJson(j as Map<String, dynamic>)).toList();

  Future<T> _get<T>(String path) async {
    try {
      final response = await _dio.get<T>(path);
      return response.data as T;
    } on DioException catch (e) {
      throw _toApiError(e);
    }
  }

  Future<T> _post<T>(
    String path,
    Object body,
    T Function(Map<String, dynamic>) parse,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(path, data: body);
      return parse(response.data!);
    } on DioException catch (e) {
      throw _toApiError(e);
    }
  }

  static ApiError _toApiError(DioException e) {
    const networkTypes = {
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
    };
    if (networkTypes.contains(e.type) || e.error is SocketException) {
      return const ApiError(ApiError.network);
    }

    final data = e.response?.data;
    final message = data is Map && data['error'] is String
        ? data['error'] as String
        : ApiError.unknown;
    return ApiError(message, statusCode: e.response?.statusCode);
  }
}
