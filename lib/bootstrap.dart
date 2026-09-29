import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/app.dart';
import 'package:gate_closes/core/airports/local_airport_registry.dart';
import 'package:gate_closes/core/config/app_config.dart';
import 'package:gate_closes/core/services/storage_service.dart';
import 'package:gate_closes/core/utils/logger.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared startup used by every entry point. Pins the chosen [config], does
/// async init (SharedPreferences, dotenv), then runs the app. Keep environment-
/// specific logic in the entry points, not here.
///
/// - `main.dart`      → `bootstrap(AppConfig.fromEnvironment())` (loads .env)
/// - `main_dev.dart`  → `bootstrap(const AppConfig.dev())`  (no .env needed)
/// - `main_prod.dart` → `bootstrap(const AppConfig.prod())` (no .env needed)
Future<void> bootstrap(AppConfig config, {String? dotEnvFile}) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load the .env file if a path is supplied (used by the default main.dart).
  if (dotEnvFile != null) {
    await dotenv.load(fileName: dotEnvFile);
    // Re-build config from the loaded dotenv values.
    AppConfig.instance = AppConfig.fromEnvironment();
  } else {
    AppConfig.instance = config;
  }

  if (AppConfig.instance.mapboxAccessToken.isNotEmpty) {
    MapboxOptions.setAccessToken(AppConfig.instance.mapboxAccessToken);
  }

  final prefs = await SharedPreferences.getInstance();

  // Load the bundled IATA airport registry so BoardingPassCoordinator can
  // resolve/validate codes offline. Must complete before any boarding-pass
  // screen mounts; `initialize()` is idempotent and safe to await here even
  // if a caller has already primed it (e.g. in tests).
  await LocalAirportRegistry.instance.initialize();

  if (AppConfig.instance.enableLogging) {
    appLogger.i(
      'Starting ${AppConfig.instance.appName} '
      '[${AppConfig.instance.environment.name}] '
      '-> ${AppConfig.instance.baseUrl}',
    );
  }

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MyApp(),
    ),
  );
}
