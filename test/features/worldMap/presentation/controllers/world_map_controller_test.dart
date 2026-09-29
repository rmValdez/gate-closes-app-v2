import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/core/location/location_coordinates.dart';
import 'package:gate_closes/core/location/location_repository.dart';
import 'package:gate_closes/core/location/location_repository_impl.dart';
import 'package:gate_closes/features/airport/domain/entities/airport_entity.dart';
import 'package:gate_closes/features/airport/domain/repositories/airport_repository.dart';
import 'package:gate_closes/features/airport/presentation/controllers/airport_controller.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_map_node_entity.dart';
import 'package:gate_closes/features/worldMap/domain/repositories/echo_map_repository.dart';
import 'package:gate_closes/features/worldMap/presentation/controllers/world_map_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockLocationRepository extends Mock implements LocationRepository {}

class MockAirportRepository extends Mock implements AirportRepository {}

class MockEchoMapRepository extends Mock implements EchoMapRepository {}

void main() {
  late ProviderContainer container;
  late MockLocationRepository mockLocationRepository;
  late MockAirportRepository mockAirportRepository;
  late MockEchoMapRepository mockEchoMapRepository;

  const tCoordinates = LocationCoordinates(latitude: 1.35, longitude: 103.99);
  const tAirports = [
    AirportEntity(
      id: 'SIN',
      name: 'Singapore Changi Airport',
      iata: 'SIN',
      distanceKm: 2.1,
    ),
  ];

  setUp(() {
    mockLocationRepository = MockLocationRepository();
    mockAirportRepository = MockAirportRepository();
    mockEchoMapRepository = MockEchoMapRepository();

    when(
      mockAirportRepository.getAirportGeoJson,
    ).thenAnswer((_) async => const Right(<String, dynamic>{}));
    when(
      mockEchoMapRepository.getNodes,
    ).thenAnswer(
      (_) async => const Right(<TerminalEchoMapNodeEntity>[]),
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('WorldMapController', () {
    test('build() fetches nearby airports in the background', () async {
      when(
        mockLocationRepository.getCurrentLocation,
      ).thenAnswer((_) async => const Right(tCoordinates));
      when(
        () => mockAirportRepository.findNearby(tCoordinates),
      ).thenAnswer((_) async => const Right(tAirports));

      container = ProviderContainer(
        overrides: [
          locationRepositoryProvider.overrideWithValue(mockLocationRepository),
          airportRepositoryProvider.overrideWithValue(mockAirportRepository),
          echoMapRepositoryProvider.overrideWithValue(
            mockEchoMapRepository,
          ),
        ],
      )..read(worldMapControllerProvider);

      await Future<void>.delayed(Duration.zero);

      final state = container.read(worldMapControllerProvider);
      expect(state.isLoading, false);
      expect(state.airports, tAirports);
      expect(state.error, isNull);
    });

    test('a failed location fetch surfaces the error', () async {
      const tFailure = PermissionFailure('Location permission denied.');
      when(
        mockLocationRepository.getCurrentLocation,
      ).thenAnswer((_) async => const Left(tFailure));

      container = ProviderContainer(
        overrides: [
          locationRepositoryProvider.overrideWithValue(mockLocationRepository),
          airportRepositoryProvider.overrideWithValue(mockAirportRepository),
          echoMapRepositoryProvider.overrideWithValue(
            mockEchoMapRepository,
          ),
        ],
      )..read(worldMapControllerProvider);

      await Future<void>.delayed(Duration.zero);

      final state = container.read(worldMapControllerProvider);
      expect(state.isLoading, false);
      expect(state.airports, isEmpty);
      expect(state.error, tFailure.message);
    });

    test('a failed airport fetch surfaces the error and keeps airports empty',
        () async {
      const tFailure = ServerFailure('Boom');
      when(
        mockLocationRepository.getCurrentLocation,
      ).thenAnswer((_) async => const Right(tCoordinates));
      when(
        () => mockAirportRepository.findNearby(tCoordinates),
      ).thenAnswer((_) async => const Left(tFailure));

      container = ProviderContainer(
        overrides: [
          locationRepositoryProvider.overrideWithValue(mockLocationRepository),
          airportRepositoryProvider.overrideWithValue(mockAirportRepository),
          echoMapRepositoryProvider.overrideWithValue(
            mockEchoMapRepository,
          ),
        ],
      )..read(worldMapControllerProvider);

      await Future<void>.delayed(Duration.zero);

      final state = container.read(worldMapControllerProvider);
      expect(state.isLoading, false);
      expect(state.airports, isEmpty);
      expect(state.error, tFailure.message);
    });
  });
}
