import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/features/auth/presentation/controllers/auth_controller.dart';
import 'package:gate_closes/features/flight/data/repositories/flight_repository_impl.dart';
import 'package:gate_closes/features/flight/domain/entities/flight_ticket_entity.dart';
import 'package:gate_closes/features/flight/domain/repositories/flight_repository.dart';

// --- Dependency wiring ---

final flightRepositoryProvider = Provider<FlightRepository>((ref) {
  return FlightRepositoryImpl(ref.watch(apiServiceProvider));
});

// --- State ---

class FlightState extends Equatable {
  const FlightState({
    this.isLoading = false,
    this.activeFlight,
    this.error,
  });

  final bool isLoading;
  final FlightTicketEntity? activeFlight;
  final String? error;

  bool get hasActiveFlight => activeFlight != null;

  FlightStatus get status =>
      activeFlight?.getStatus() ?? FlightStatus.completed;

  Duration get remainingDwellTime =>
      activeFlight?.getRemainingDwellTime() ?? Duration.zero;

  bool get isInsideDwellWindow => activeFlight?.isInsideDwellWindow() ?? false;

  FlightState copyWith({
    bool? isLoading,
    FlightTicketEntity? activeFlight,
    String? error,
  }) {
    return FlightState(
      isLoading: isLoading ?? this.isLoading,
      activeFlight: activeFlight ?? this.activeFlight,
      error: error,
    );
  }

  @override
  List<Object?> get props => [isLoading, activeFlight, error];
}

// --- Controller ---

class FlightController extends Notifier<FlightState> {
  @override
  FlightState build() {
    // Reset whenever the signed-in user changes, so a previous account's
    // flight never lingers after logout/login.
    ref.watch(authControllerProvider.select((s) => s.user?.id));
    return const FlightState();
  }

  /// Hydrates current active flight ticket from backend.
  Future<void> fetchActiveFlight() async {
    state = state.copyWith(isLoading: true);
    final repo = ref.read(flightRepositoryProvider);
    final result = await repo.getActiveFlightTicket();

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        error: failure.message,
      ),
      // Assign directly: copyWith can't clear activeFlight, and a null here
      // (flight ended/removed server-side) must replace the stale ticket.
      (flight) => state = FlightState(activeFlight: flight),
    );
  }

  /// Saves (creates or updates) the flight ticket on backend and
  /// rehydrates state.
  Future<bool> saveFlightTicket({
    required String flightNumber,
    required String fromAirport,
    required String toAirport,
    required DateTime departureDateTime,
    DateTime? returnDateTime,
    DateTime? arrivalDateTime,
    DateTime? boardingDateTime,
    String? terminal,
    String? gate,
    String? seat,
    String? idempotencyKey,
  }) async {
    state = state.copyWith(isLoading: true);
    final repo = ref.read(flightRepositoryProvider);

    final result = state.activeFlight != null
        ? await repo.updateFlightTicket(
            flightNumber: flightNumber,
            fromAirport: fromAirport,
            toAirport: toAirport,
            departureDateTime: departureDateTime,
            returnDateTime: returnDateTime,
            arrivalDateTime: arrivalDateTime,
            boardingDateTime: boardingDateTime,
            terminal: terminal,
            gate: gate,
            seat: seat,
          )
        : await repo.createFlightTicket(
            flightNumber: flightNumber,
            fromAirport: fromAirport,
            toAirport: toAirport,
            departureDateTime: departureDateTime,
            returnDateTime: returnDateTime,
            arrivalDateTime: arrivalDateTime,
            boardingDateTime: boardingDateTime,
            terminal: terminal,
            gate: gate,
            seat: seat,
            idempotencyKey: idempotencyKey,
          );

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (_) async {
        await fetchActiveFlight();
        return true;
      },
    );
  }

  /// Removes active flight ticket.
  Future<bool> deleteFlightTicket() async {
    state = state.copyWith(isLoading: true);
    final repo = ref.read(flightRepositoryProvider);
    final result = await repo.deleteFlightTicket();

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (_) {
        state = const FlightState();
        return true;
      },
    );
  }
}

final flightControllerProvider =
    NotifierProvider<FlightController, FlightState>(FlightController.new);
