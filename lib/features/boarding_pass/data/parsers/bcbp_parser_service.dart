import 'package:gate_closes/core/airports/airport_code_validator.dart';
import 'package:gate_closes/features/boarding_pass/domain/entities/parsed_flight.dart';
import 'package:gate_closes/features/boarding_pass/domain/enums/boarding_pass_source.dart';
import 'package:gate_closes/features/boarding_pass/domain/services/confidence_engine.dart';
import 'package:gate_closes/features/boarding_pass/domain/services/flight_normalizer.dart';

/// Comprehensive IATA Resolution 792 / 791 BCBP Parser.
class BcbpParserService {
  const BcbpParserService({required this.validator});
  final AirportCodeValidator validator;

  /// Parses an IATA BCBP string into a ParsedFlight.
  /// Returns null if format is not BCBP compliant or lacks minimal structure.
  ParsedFlight? parse(String rawData, {DateTime? referenceDate}) {
    final trimmed = rawData.trim();
    if (!trimmed.startsWith('M') || trimmed.length < 47) {
      return null;
    }

    try {
      // Positions 2–29 hold the passenger name and booking reference (PNR).
      // Deliberately never read: Core Invariant 5 — passenger identity is not
      // extracted, displayed or kept (see BOARDING_PASS_INTELLIGENCE_PLAN.md).

      // Origin Airport IATA (index 30, 3 chars)
      final fromAirport = trimmed.substring(30, 33).trim().toUpperCase();

      // Destination Airport IATA (index 33, 3 chars)
      final toAirport = trimmed.substring(33, 36).trim().toUpperCase();

      // Operating Carrier / Airline (index 36, 3 chars)
      final airline = trimmed.substring(36, 39).trim().toUpperCase();

      // Flight Number (index 39, 5 chars)
      final rawFlightNum = trimmed.substring(39, 44).trim();
      final flightNumber =
          FlightNormalizer.normalizeFlightNumber('$airline$rawFlightNum');

      // Date of Flight (Julian Day, index 44, 3 chars)
      final julianDayStr = trimmed.substring(44, 47).trim();
      final julianDay = int.tryParse(julianDayStr);

      DateTime? departureDate;
      if (julianDay != null && julianDay >= 1 && julianDay <= 366) {
        departureDate =
            FlightNormalizer.julianToDateTime(julianDay, referenceDate);
      }

      // Seat Number (index 48, 4 chars if present)
      String? seat;
      if (trimmed.length >= 52) {
        final seatCandidate = trimmed.substring(48, 52).trim();
        if (seatCandidate.isNotEmpty) {
          seat = seatCandidate;
        }
      }

      // Origin & Dest IATA validity checks
      final isOriginValid = validator.isValidIata(fromAirport);
      final isDestValid = validator.isValidIata(toAirport);
      final originRef = validator.resolveAirport(fromAirport);

      final confidence = ConfidenceEngine.calculate(
        hasValidFlightNumber: flightNumber.isNotEmpty,
        isOriginValidIata: isOriginValid,
        isDestValidIata: isDestValid,
        hasValidDate: departureDate != null,
        hasTime: false,
        isBcbpDecoded: true,
      );

      return ParsedFlight(
        flightNumber: flightNumber,
        originIata: fromAirport,
        destinationIata: toAirport,
        departureDateTime: departureDate,
        departureTimezone: originRef?.timezone ?? 'UTC',
        seat: seat,
        source: BoardingPassSource.bcbp,
        confidence: confidence,
      );
    } on Object catch (_) {
      return null;
    }
  }
}
