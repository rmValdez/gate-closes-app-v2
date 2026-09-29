import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/location/location_coordinates.dart';
import 'package:gate_closes/core/location/location_repository_impl.dart';
import 'package:gate_closes/features/airport/data/repositories/airport_repository_impl.dart';
import 'package:gate_closes/features/airport/domain/entities/airport_entity.dart';
import 'package:gate_closes/features/airport/domain/repositories/airport_repository.dart';
import 'package:gate_closes/features/auth/presentation/controllers/auth_controller.dart';

// --- Dependency wiring ---

final airportRepositoryProvider = Provider<AirportRepository>((ref) {
  return AirportRepositoryImpl(ref.watch(apiServiceProvider));
});

// --- State ---

class AirportState extends Equatable {
  const AirportState({
    this.isDetecting = false,
    this.coordinates,
    this.airport,
    this.error,
  });

  final bool isDetecting;
  final LocationCoordinates? coordinates;
  final AirportEntity? airport;
  final String? error;

  bool get isInsideAirport =>
      airport?.detectionState == AirportDetectionState.insideAirport;

  AirportState copyWith({
    bool? isDetecting,
    LocationCoordinates? coordinates,
    AirportEntity? airport,
    String? error,
  }) {
    return AirportState(
      isDetecting: isDetecting ?? this.isDetecting,
      coordinates: coordinates ?? this.coordinates,
      airport: airport ?? this.airport,
      error: error,
    );
  }

  @override
  List<Object?> get props => [isDetecting, coordinates, airport, error];
}

// --- Controller ---

class AirportController extends Notifier<AirportState> {
  @override
  AirportState build() {
    return const AirportState();
  }

  /// Acquires user location, quantizes coordinates, and queries the backend
  /// for current airport boundary status.
  Future<void> detectAirport() async {
    state = state.copyWith(isDetecting: true);

    final locationRepo = ref.read(locationRepositoryProvider);
    final airportRepo = ref.read(airportRepositoryProvider);

    final locationResult = await locationRepo.getCurrentLocation();

    await locationResult.fold(
      (failure) async {
        state = state.copyWith(
          isDetecting: false,
          error: failure.message,
        );
      },
      (coords) async {
        state = state.copyWith(coordinates: coords);

        final airportResult = await airportRepo.checkInsideAirport(coords);

        airportResult.fold(
          (failure) {
            state = state.copyWith(
              isDetecting: false,
              error: failure.message,
            );
          },
          (airport) {
            state = state.copyWith(
              isDetecting: false,
              airport: airport,
            );
          },
        );
      },
    );
  }

  /// Sets manual coordinates (useful for emulator mock GPS testing,
  /// e.g. Changi SIN).
  Future<void> setManualCoordinates(LocationCoordinates coords) async {
    state = state.copyWith(isDetecting: true, coordinates: coords);
    final airportRepo = ref.read(airportRepositoryProvider);
    final result = await airportRepo.checkInsideAirport(coords);

    result.fold(
      (failure) =>
          state = state.copyWith(isDetecting: false, error: failure.message),
      (airport) => state = state.copyWith(isDetecting: false, airport: airport),
    );
  }
}

final airportControllerProvider =
    NotifierProvider<AirportController, AirportState>(AirportController.new);
