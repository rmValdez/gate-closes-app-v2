import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/location/location_repository_impl.dart';
import 'package:gate_closes/features/airport/domain/entities/airport_entity.dart';
import 'package:gate_closes/features/airport/presentation/controllers/airport_controller.dart';
import 'package:gate_closes/features/auth/presentation/controllers/auth_controller.dart';
import 'package:gate_closes/features/worldMap/data/repositories/echo_map_repository_impl.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_map_node_entity.dart';
import 'package:gate_closes/features/worldMap/domain/repositories/echo_map_repository.dart';

final echoMapRepositoryProvider = Provider<EchoMapRepository>((ref) {
  return EchoMapRepositoryImpl(ref.watch(apiServiceProvider));
});

class WorldMapState extends Equatable {
  const WorldMapState({
    this.isLoading = false,
    this.airports = const [],
    this.airportBoundariesGeoJson,
    this.echoNodes = const [],
    this.selectedAirport,
    this.error,
  });

  final bool isLoading;
  final List<AirportEntity> airports;
  final Map<String, dynamic>? airportBoundariesGeoJson;
  final List<TerminalEchoMapNodeEntity> echoNodes;
  final AirportEntity? selectedAirport;
  final String? error;

  WorldMapState copyWith({
    bool? isLoading,
    List<AirportEntity>? airports,
    Map<String, dynamic>? airportBoundariesGeoJson,
    List<TerminalEchoMapNodeEntity>? echoNodes,
    AirportEntity? selectedAirport,
    String? error,
  }) =>
      WorldMapState(
        isLoading: isLoading ?? this.isLoading,
        airports: airports ?? this.airports,
        airportBoundariesGeoJson:
            airportBoundariesGeoJson ?? this.airportBoundariesGeoJson,
        echoNodes: echoNodes ?? this.echoNodes,
        selectedAirport: selectedAirport ?? this.selectedAirport,
        error: error,
      );

  @override
  List<Object?> get props => [
        isLoading,
        airports,
        airportBoundariesGeoJson,
        echoNodes,
        selectedAirport,
        error,
      ];
}

class WorldMapController extends Notifier<WorldMapState> {
  @override
  WorldMapState build() {
    unawaited(Future.microtask(initMapData));
    return const WorldMapState(isLoading: true);
  }

  Future<void> initMapData() async {
    state = state.copyWith(isLoading: true);

    final locationRepo = ref.read(locationRepositoryProvider);
    final airportRepo = ref.read(airportRepositoryProvider);
    final echoMapRepo = ref.read(echoMapRepositoryProvider);

    // 1. Load airport boundaries GeoJSON
    final boundaryResult = await airportRepo.getAirportGeoJson();
    final boundaryData = boundaryResult.fold(
      (_) => null,
      (data) => data,
    );

    // 2. Load echo pins GeoJSON
    final echoNodes = (await echoMapRepo.getNodes()).getOrElse(
      (_) => const <TerminalEchoMapNodeEntity>[],
    );

    // 3. Resolve user location and nearby airports
    final locationResult = await locationRepo.getCurrentLocation();
    await locationResult.fold(
      (failure) async {
        state = state.copyWith(
          isLoading: false,
          airportBoundariesGeoJson: boundaryData,
          echoNodes: echoNodes,
          error: failure.message,
        );
      },
      (coordinates) async {
        final airportsResult = await airportRepo.findNearby(coordinates);
        airportsResult.fold(
          (failure) => state = state.copyWith(
            isLoading: false,
            airportBoundariesGeoJson: boundaryData,
            echoNodes: echoNodes,
            error: failure.message,
          ),
          (airports) {
            state = state.copyWith(
              isLoading: false,
              airports: airports,
              selectedAirport: airports.isNotEmpty ? airports.first : null,
              airportBoundariesGeoJson: boundaryData,
              echoNodes: echoNodes,
            );
          },
        );
      },
    );
  }

  Future<void> fetchEchoNodesForBounds({
    required double west,
    required double south,
    required double east,
    required double north,
  }) async {
    final res = await ref.read(echoMapRepositoryProvider).getNodes(
          west: west,
          south: south,
          east: east,
          north: north,
        );
    res.fold((_) => null, (nodes) => state = state.copyWith(echoNodes: nodes));
  }

  void selectAirport(AirportEntity airport) {
    state = state.copyWith(selectedAirport: airport);
  }
}

final worldMapControllerProvider =
    NotifierProvider<WorldMapController, WorldMapState>(
  WorldMapController.new,
);
