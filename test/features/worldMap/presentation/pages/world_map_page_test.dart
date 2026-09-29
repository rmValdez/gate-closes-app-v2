import 'package:flutter/material.dart';
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
import 'package:gate_closes/features/worldMap/presentation/pages/world_map_page.dart';
import 'package:gate_closes/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockLocationRepository extends Mock implements LocationRepository {}

class MockAirportRepository extends Mock implements AirportRepository {}

class MockEchoMapRepository extends Mock implements EchoMapRepository {}

const _tCoordinates = LocationCoordinates(latitude: 1.35, longitude: 103.99);

void main() {
  testWidgets(
    'WorldMapPage renders the fetched nearby airports with no layout errors',
    (tester) async {
      final mockLocationRepository = MockLocationRepository();
      final mockAirportRepository = MockAirportRepository();
      final mockEchoMapRepository = MockEchoMapRepository();

      when(
        mockAirportRepository.getAirportGeoJson,
      ).thenAnswer((_) async => const Right(<String, dynamic>{}));
      when(
        mockEchoMapRepository.getNodes,
      ).thenAnswer(
        (_) async => const Right(<TerminalEchoMapNodeEntity>[]),
      );

      when(
        mockLocationRepository.getCurrentLocation,
      ).thenAnswer((_) async => const Right(_tCoordinates));
      when(
        () => mockAirportRepository.findNearby(_tCoordinates),
      ).thenAnswer(
        (_) async => const Right([
          AirportEntity(
            id: 'SIN',
            name: 'Singapore Changi Airport',
            iata: 'SIN',
            distanceKm: 0.8,
          ),
          AirportEntity(
            id: 'JHB',
            name: 'Senai International Airport',
            iata: 'JHB',
            distanceKm: 45.2,
          ),
        ]),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            locationRepositoryProvider.overrideWithValue(
              mockLocationRepository,
            ),
            airportRepositoryProvider.overrideWithValue(
              mockAirportRepository,
            ),
            echoMapRepositoryProvider.overrideWithValue(
              mockEchoMapRepository,
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: WorldMapPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In spatial mode, current selected airport is displayed
      expect(find.text('Singapore Changi Airport'), findsOneWidget);

      // Switch to list view to verify both airports
      await tester.tap(find.byIcon(Icons.view_list_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Singapore Changi Airport'), findsOneWidget);
      expect(find.text('Senai International Airport'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'WorldMapPage shows an empty state with no results in list mode',
    (tester) async {
      final mockLocationRepository = MockLocationRepository();
      final mockAirportRepository = MockAirportRepository();
      final mockEchoMapRepository = MockEchoMapRepository();

      when(
        mockAirportRepository.getAirportGeoJson,
      ).thenAnswer((_) async => const Right(<String, dynamic>{}));
      when(
        mockEchoMapRepository.getNodes,
      ).thenAnswer(
        (_) async => const Right(<TerminalEchoMapNodeEntity>[]),
      );

      when(
        mockLocationRepository.getCurrentLocation,
      ).thenAnswer((_) async => const Right(_tCoordinates));
      when(
        () => mockAirportRepository.findNearby(_tCoordinates),
      ).thenAnswer((_) async => const Right([]));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            locationRepositoryProvider.overrideWithValue(
              mockLocationRepository,
            ),
            airportRepositoryProvider.overrideWithValue(mockAirportRepository),
            echoMapRepositoryProvider.overrideWithValue(
              mockEchoMapRepository,
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: WorldMapPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to list view to see empty state
      await tester.tap(find.byIcon(Icons.view_list_rounded));
      await tester.pumpAndSettle();

      expect(find.text('No nearby airports'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
      'WorldMapPage shows a retry option when the fetch fails in list mode',
      (tester) async {
    final mockLocationRepository = MockLocationRepository();
    final mockAirportRepository = MockAirportRepository();
    final mockEchoMapRepository = MockEchoMapRepository();

    when(
      mockAirportRepository.getAirportGeoJson,
    ).thenAnswer((_) async => const Right(<String, dynamic>{}));
    when(
      mockEchoMapRepository.getNodes,
    ).thenAnswer(
      (_) async => const Right(<TerminalEchoMapNodeEntity>[]),
    );

    when(
      mockLocationRepository.getCurrentLocation,
    ).thenAnswer((_) async => const Left(NetworkFailure()));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationRepositoryProvider.overrideWithValue(mockLocationRepository),
          airportRepositoryProvider.overrideWithValue(mockAirportRepository),
          echoMapRepositoryProvider.overrideWithValue(
            mockEchoMapRepository,
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WorldMapPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to list view to see error/retry state
    await tester.tap(find.byIcon(Icons.view_list_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
