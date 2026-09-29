import 'package:equatable/equatable.dart';
import 'package:gate_closes/features/boarding_pass/domain/entities/parse_confidence.dart';
import 'package:gate_closes/features/boarding_pass/domain/enums/boarding_pass_source.dart';

/// Candidate flight parsed from a boarding pass prior to persistence.
///
/// Carries flight details only. Passenger name, booking reference (PNR) and
/// the raw barcode/OCR payload are never part of it (Core Invariant 5).
class ParsedFlight extends Equatable {
  const ParsedFlight({
    required this.flightNumber,
    required this.originIata,
    required this.destinationIata,
    required this.source,
    required this.confidence,
    this.departureDateTime,
    this.departureTimezone,
    this.boardingDateTime,
    this.terminal,
    this.gate,
    this.seat,
  });

  final String flightNumber;
  final String originIata;
  final String destinationIata;
  final DateTime? departureDateTime;
  final String? departureTimezone;
  final DateTime? boardingDateTime;
  final String? terminal;
  final String? gate;
  final String? seat;
  final BoardingPassSource source;
  final ParseConfidence confidence;

  /// Whether the core routing fields (flight #, origin, destination) are
  /// present.
  bool get hasRequiredRoute =>
      flightNumber.trim().isNotEmpty &&
      originIata.trim().isNotEmpty &&
      destinationIata.trim().isNotEmpty;

  /// Whether a departure schedule could be parsed.
  bool get hasDepartureSchedule => departureDateTime != null;

  ParsedFlight copyWith({
    String? flightNumber,
    String? originIata,
    String? destinationIata,
    DateTime? departureDateTime,
    String? departureTimezone,
    DateTime? boardingDateTime,
    String? terminal,
    String? gate,
    String? seat,
    BoardingPassSource? source,
    ParseConfidence? confidence,
  }) {
    return ParsedFlight(
      flightNumber: flightNumber ?? this.flightNumber,
      originIata: originIata ?? this.originIata,
      destinationIata: destinationIata ?? this.destinationIata,
      departureDateTime: departureDateTime ?? this.departureDateTime,
      departureTimezone: departureTimezone ?? this.departureTimezone,
      boardingDateTime: boardingDateTime ?? this.boardingDateTime,
      terminal: terminal ?? this.terminal,
      gate: gate ?? this.gate,
      seat: seat ?? this.seat,
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
    );
  }

  @override
  List<Object?> get props => [
        flightNumber,
        originIata,
        destinationIata,
        departureDateTime,
        departureTimezone,
        boardingDateTime,
        terminal,
        gate,
        seat,
        source,
        confidence,
      ];
}
