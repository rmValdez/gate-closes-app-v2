import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gate_closes/core/config/environment.dart';

/// Per-environment settings, fixed at startup.
///
/// One [AppConfig] is chosen by the entry point (main_dev/main_prod) and
/// assigned to [instance] inside `bootstrap()`. Read it anywhere via
/// `AppConfig.instance`.
///
/// The default entry point (`main.dart`) builds it via
/// [AppConfig.fromEnvironment], which reads from the `.env.*` asset loaded
/// by `flutter_dotenv`.
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.appName,
    required this.baseUrl,
    this.mapboxAccessToken = '',
    this.enableLogging = false,
  });

  /// Builds config from `flutter_dotenv` values loaded at runtime.
  /// Used by the default entry point (`main.dart`).
  factory AppConfig.fromEnvironment() {
    final envString = dotenv.env['ENVIRONMENT'] ?? 'dev';
    return AppConfig(
      environment: envString == 'prod' ? Environment.prod : Environment.dev,
      appName: dotenv.env['APP_NAME'] ?? 'Gate Closes',
      baseUrl: dotenv.env['BASE_URL'] ?? '',
      mapboxAccessToken: dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '',
      enableLogging: (dotenv.env['ENABLE_LOGGING'] ??
                  (envString != 'prod' ? 'true' : 'false'))
              .toLowerCase() ==
          'true',
    );
  }

  /// Explicit development config used by `main_dev.dart` — works without any
  /// `.env` file, with logging on and pointed at the sample backend.
  const AppConfig.dev()
      : environment = Environment.dev,
        appName = 'Gate Closes (Dev)',
        baseUrl = 'http://10.0.2.2:3001/api',
        mapboxAccessToken = _mapboxTokenDefine,
        enableLogging = true;

  /// Explicit production config used by `main_prod.dart` — logging off,
  /// real backend URL.
  const AppConfig.prod()
      : environment = Environment.prod,
        appName = 'Gate Closes',
        baseUrl = 'https://api.gatecloses.com/api',
        mapboxAccessToken = _mapboxTokenDefine,
        enableLogging = false;

  final Environment environment;
  final String appName;
  final String baseUrl;
  final String mapboxAccessToken;
  final bool enableLogging;

  bool get isDev => environment == Environment.dev;
  bool get isProd => environment == Environment.prod;

  /// Mapbox public token for the define-based entry points (main_dev /
  /// main_prod), which don't load a `.env` file:
  /// `flutter run -t lib/main_prod.dart --dart-define=MAPBOX_ACCESS_TOKEN=pk...`
  /// Without it the map can't render.
  static const String _mapboxTokenDefine =
      String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

  /// Set once by `bootstrap()` before `runApp`. Reading it before then throws.
  static late AppConfig instance;
}
