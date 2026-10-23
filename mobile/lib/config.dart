import 'package:flutter/foundation.dart';

/// Where the app finds the API.
///
/// Defaults to the API running on this computer: the iOS simulator reaches it at
/// `localhost`, the Android emulator at `10.0.2.2`. Override for a real device or
/// production with: `flutter run --dart-define=API_BASE_URL=https://...`
abstract final class AppConfig {
  static const _override = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:5050'
        : 'http://localhost:5050';
  }
}
