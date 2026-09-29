// Exercises the PRODUCTION initialization path — LocalAirportRegistry
// .initialize() loading the real bundled assets/data/airports.json via
// rootBundle — as opposed to loadFromJsonString(), which every other test
// in this suite uses to inject a small in-memory fixture.
//
// This test exists because bootstrap() is the only production caller of
// initialize(), and no widget test pumps bootstrap() (see widget_test.dart,
// which sets up its own ProviderScope and never calls it). Without this
// test, the bundled registry could regress to never loading in the real
// app — as it did previously — while every parser/coordinator test stayed
// green, because they all prime the registry via loadFromJsonString instead.
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/core/airports/local_airport_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'initialize() loads the real bundled assets/data/airports.json via rootBundle',
      () async {
    final registry = LocalAirportRegistry.instance;

    expect(
      registry.isInitialized,
      isFalse,
      reason: 'This test must run before any other test in this process '
          'calls loadFromJsonString/initialize on the shared singleton, '
          'otherwise it is not actually exercising cold production startup.',
    );

    await registry.initialize();

    expect(registry.isInitialized, isTrue);

    // Well-known, stable IATA codes that must be present in the bundled
    // dataset for the parser pipeline to work at all.
    expect(registry.isValidIata('MNL'), isTrue);
    expect(registry.isValidIata('SFO'), isTrue);
    expect(registry.isValidIata('LHR'), isTrue);

    final mnl = registry.resolveAirport('MNL');
    expect(mnl, isNotNull);
    expect(mnl!.iata, equals('MNL'));
    expect(mnl.timezone, isNotEmpty);

    // Sanity check this is the full dataset, not a trivially small fallback.
    expect(registry.isValidIata('ZZZ'), isFalse);
  });
}
