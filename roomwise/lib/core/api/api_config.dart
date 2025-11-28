import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class ApiConfig {
  static const String _hostFromEnv = String.fromEnvironment(
    'ROOMWISE_API_HOST',
  );

  static String baseUrl({String? overrideHost}) {
    final host =
        overrideHost ?? (_hostFromEnv.isNotEmpty ? _hostFromEnv : _defaultHost);
    return 'http://$host:5184/api';
  }

  static String get _defaultHost {
    if (kIsWeb) return 'localhost';
    return defaultTargetPlatform == TargetPlatform.android
        ? '10.0.2.2'
        : 'localhost';
  }
}
