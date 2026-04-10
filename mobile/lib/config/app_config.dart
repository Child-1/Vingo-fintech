import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Centralized app configuration.
///
/// Override at build time for any environment:
///   flutter run --dart-define=API_BASE_URL=https://api.myraba.ng
///   flutter build apk --dart-define=API_BASE_URL=https://api.myraba.ng
///   flutter build ipa --dart-define=API_BASE_URL=https://api.myraba.ng
class AppConfig {
  AppConfig._();

  /// The API base URL, resolved in this priority order:
  ///   1. --dart-define=API_BASE_URL=... (build-time override — use for staging/prod)
  ///   2. Platform-aware localhost for local development
  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;

    if (kIsWeb) return 'http://localhost:8080';
    if (Platform.isAndroid) return 'http://10.0.2.2:8080'; // Android emulator tunnels localhost here
    if (Platform.isIOS || Platform.isMacOS) return 'http://localhost:8080';
    return 'http://localhost:8080'; // Linux/Windows desktop
  }

  static const Duration requestTimeout = Duration(seconds: 30);
}
