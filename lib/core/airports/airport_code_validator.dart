import 'package:gate_closes/core/airports/airport_reference.dart';

/// Contract for synchronous/fast offline IATA code validation and airport metadata resolution.
abstract interface class AirportCodeValidator {
  /// Returns true if the given code is a valid, recognized 3-letter IATA code.
  bool isValidIata(String iata);

  /// Resolves the airport metadata if known; returns null otherwise.
  AirportReference? resolveAirport(String iata);
}
