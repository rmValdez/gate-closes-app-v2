import 'package:gate_closes/bootstrap.dart';
import 'package:gate_closes/core/config/app_config.dart';

/// Default entry point for a bare `flutter run` (no `-t`).
/// Loads a `.env.*` file at runtime via flutter_dotenv: `.env.prod` when
/// launched with `--dart-define-from-file=.env.prod` (which defines
/// `ENVIRONMENT=prod`), otherwise `.env.dev`. Previously this always loaded
/// `.env.dev`, so "prod" launches/builds silently used the dev backend.
///
/// For explicit, define-free targets use `lib/main_dev.dart` or
/// `lib/main_prod.dart`.
Future<void> main() => bootstrap(
      const AppConfig.dev(), // fallback, overridden after dotenv loads
      dotEnvFile: const String.fromEnvironment('ENVIRONMENT') == 'prod'
          ? '.env.prod'
          : '.env.dev',
    );
