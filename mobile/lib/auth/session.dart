import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_client.dart';

/// Where the session is persisted. The app uses the device keychain/keystore;
/// tests use [MemoryTokenStore].
abstract class TokenStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureTokenStore implements TokenStore {
  const SecureTokenStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class MemoryTokenStore implements TokenStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// The signed-in player, if any. The router listens to this to decide between
/// the Welcome flow and Home.
class Session extends ChangeNotifier {
  Session(this._store);

  final TokenStore _store;

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  String? _token;
  AppUser? _user;
  bool _ready = false;

  String? get token => _token;
  AppUser? get user => _user;
  bool get isLoggedIn => _token != null && _user != null;

  /// False while the splash screen is still checking the saved login.
  bool get ready => _ready;

  /// Runs once at launch: loads the saved login and, if there is one, asks the API
  /// whether it's still valid. A rejected token signs the player out; if the API
  /// can't be reached, the saved login is kept so offline players aren't kicked out.
  Future<void> start(
    ApiClient api, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    await restore();
    if (!isLoggedIn) return;
    try {
      final user = await api.me().timeout(timeout);
      _user = user;
      await _store.write(_userKey, jsonEncode(user.toJson()));
    } on ApiError catch (e) {
      if (e.statusCode == 401) await signOut();
    } on TimeoutException {
      // Slow network: carry on with the saved login.
    }
  }

  /// Lets the router leave the splash screen.
  void markReady() {
    if (_ready) return;
    _ready = true;
    notifyListeners();
  }

  /// Loads a saved session on launch, so returning players skip the login screen.
  Future<void> restore() async {
    try {
      final token = await _store.read(_tokenKey);
      final userJson = await _store.read(_userKey);
      if (token != null && userJson != null) {
        _token = token;
        _user = AppUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      }
    } catch (_) {
      // Unreadable storage just means "not logged in".
      await signOut();
    }
  }

  Future<void> signIn(AuthResult result) async {
    _token = result.token;
    _user = result.user;
    await _store.write(_tokenKey, result.token);
    await _store.write(_userKey, jsonEncode(result.user.toJson()));
    notifyListeners();
  }

  Future<void> signOut() async {
    final wasLoggedIn = isLoggedIn;
    _token = null;
    _user = null;
    await _store.delete(_tokenKey);
    await _store.delete(_userKey);
    if (wasLoggedIn) notifyListeners();
  }
}
