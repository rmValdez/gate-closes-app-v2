import 'package:equatable/equatable.dart';

/// Explicit status of a flight ticket based on dwell window and departure time.
enum FlightStatus {
  upcoming,
  active,
  departed,
  completed,
}

/// Domain entity representing a traveler's flight lifecycle context.
class FlightTicketEntity extends Equatable {
  const FlightTicketEntity({
    required this.id,
    required this.userId,
    required this.flightNumber,
    required this.fromAirport,
    required this.toAirport,
    required this.departureDateTime,
    this.returnDateTime,
    this.arrivalDateTime,
    this.boardingDateTime,
    this.fromAirportName,
    this.toAirportName,
    this.terminal,
    this.gate,
    this.seat,
  });

  final String id;
  final String userId;
  final String flightNumber;
  final String fromAirport;
  final String toAirport;
  final DateTime departureDateTime;
  final DateTime? returnDateTime;
  final DateTime? arrivalDateTime;
  final DateTime? boardingDateTime;
  final String? fromAirportName;
  final String? toAirportName;
  final String? terminal;
  final String? gate;
  final String? seat;

  /// Evaluates current lifecycle status based on a given point in time
  /// (defaulting to DateTime.now()).
  /// Dwell window is active from 6 hours prior to departure until departure.
  FlightStatus getStatus([DateTime? now]) {
    final current = now ?? DateTime.now();

    if (current
        .isBefore(departureDateTime.subtract(const Duration(hours: 6)))) {
      return FlightStatus.upcoming;
    } else if (current.isBefore(departureDateTime)) {
      return FlightStatus.active;
    } else if (arrivalDateTime != null && current.isBefore(arrivalDateTime!)) {
      return FlightStatus.departed;
    } else {
      return FlightStatus.completed;
    }
  }

  /// Calculates remaining duration until departure.
  /// Returns Duration.zero if already departed.
  Duration getRemainingDwellTime([DateTime? now]) {
    final current = now ?? DateTime.now();
    if (current.isAfter(departureDateTime)) {
      return Duration.zero;
    }
    return departureDateTime.difference(current);
  }

  /// Whether the user is currently inside the eligible gate dwell window
  /// (within 6 hours before departure time).
  bool isInsideDwellWindow([DateTime? now]) {
    final status = getStatus(now);
    return status == FlightStatus.active;
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        flightNumber,
        fromAirport,
        toAirport,
        departureDateTime,
        returnDateTime,
        arrivalDateTime,
        boardingDateTime,
        fromAirportName,
        toAirportName,
        terminal,
        gate,
        seat,
      ];
}
