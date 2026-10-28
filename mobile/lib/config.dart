import 'package:flutter/foundation.dart';

/// Where the app finds the API.
///
/// Release builds use the live API on Azure. Debug runs default to the API on this
/// computer: the iOS simulator reaches it at `localhost`, the Android emulator at
/// `10.0.2.2`. Override either with `--dart-define=API_BASE_URL=https://...`, e.g.
/// `flutter run --dart-define=API_BASE_URL=https://dykb-api-csbb.azurewebsites.net` to play against Azure.
abstract final class AppConfig {
  static const _override = String.fromEnvironment('API_BASE_URL');

  /// The live API (Azure App Service, Central US).
  static const production = 'https://dykb-api-csbb.azurewebsites.net';

  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    if (kReleaseMode) return production;
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:5050'
        : 'http://localhost:5050';
  }
}
