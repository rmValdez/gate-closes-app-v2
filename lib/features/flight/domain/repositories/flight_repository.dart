import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/features/flight/domain/entities/flight_ticket_entity.dart';

abstract class FlightRepository {
  /// Loads current user's active flight ticket.
  Future<Either<Failure, FlightTicketEntity?>> getActiveFlightTicket();

  /// Creates a new flight ticket for the current user.
  Future<Either<Failure, String>> createFlightTicket({
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
  });

  /// Updates an existing flight ticket for the current user.
  Future<Either<Failure, String>> updateFlightTicket({
    String? flightNumber,
    String? fromAirport,
    String? toAirport,
    DateTime? departureDateTime,
    DateTime? returnDateTime,
    DateTime? arrivalDateTime,
    DateTime? boardingDateTime,
    String? terminal,
    String? gate,
    String? seat,
  });

  /// Deletes or dismisses the user's flight ticket.
  Future<Either<Failure, void>> deleteFlightTicket();
}
