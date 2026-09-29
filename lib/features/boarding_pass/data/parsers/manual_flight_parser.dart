import 'package:gate_closes/core/airports/airport_code_validator.dart';
import 'package:gate_closes/features/boarding_pass/domain/entities/parse_confidence.dart';
import 'package:gate_closes/features/boarding_pass/domain/entities/parsed_flight.dart';
import 'package:gate_closes/features/boarding_pass/domain/enums/boarding_pass_source.dart';
import 'package:gate_closes/features/boarding_pass/domain/services/flight_normalizer.dart';

/// Wraps structured user input into a ParsedFlight domain model with verified
/// confidence.
class ManualFlightParser {
  const ManualFlightParser({required this.validator});
  final AirportCodeValidator validator;

  ParsedFlight parse({
    required String flightNumber,
    required String originIata,
    required String destinationIata,
    DateTime? departureDateTime,
    String? gate,
    String? seat,
  }) {
    final cleanFlight = FlightNormalizer.normalizeFlightNumber(flightNumber);
    final cleanOrigin = originIata.trim().toUpperCase();
    final cleanDest = destinationIata.trim().toUpperCase();

    final isOriginValid = validator.isValidIata(cleanOrigin);
    final isDestValid = validator.isValidIata(cleanDest);
    final originRef = validator.resolveAirport(cleanOrigin);

    final confidence = ParseConfidence(
      flightNumber: cleanFlight.isNotEmpty ? 1.0 : 0.0,
      origin: isOriginValid ? 1.0 : 0.5,
      destination: isDestValid ? 1.0 : 0.5,
      departureDate: departureDateTime != null ? 1.0 : 0.0,
      departureTime: departureDateTime != null ? 1.0 : 0.0,
      overall:
          isOriginValid && isDestValid && cleanFlight.isNotEmpty ? 0.95 : 0.60,
    );

    return ParsedFlight(
      flightNumber: cleanFlight,
      originIata: cleanOrigin,
      destinationIata: cleanDest,
      departureDateTime: departureDateTime,
      departureTimezone: originRef?.timezone ?? 'UTC',
      gate: gate?.trim().isNotEmpty == true ? gate!.trim() : null,
      seat: seat?.trim().isNotEmpty == true ? seat!.trim() : null,
      source: BoardingPassSource.manual,
      confidence: confidence,
    );
  }
}
