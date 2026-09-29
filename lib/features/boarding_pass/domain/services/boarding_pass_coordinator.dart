import 'package:gate_closes/core/airports/airport_code_validator.dart';
import 'package:gate_closes/features/boarding_pass/data/parsers/bcbp_parser_service.dart';
import 'package:gate_closes/features/boarding_pass/data/parsers/manual_flight_parser.dart';
import 'package:gate_closes/features/boarding_pass/data/parsers/ocr_parser_service.dart';
import 'package:gate_closes/features/boarding_pass/domain/entities/parsed_flight.dart';

/// Top-level coordinator that dispatches between BCBP barcode, OCR text, and
/// manual input.
class BoardingPassCoordinator {
  BoardingPassCoordinator({required this.validator}) {
    _bcbpParser = BcbpParserService(validator: validator);
    _ocrParser = OcrParserService(validator: validator);
    _manualParser = ManualFlightParser(validator: validator);
  }
  final AirportCodeValidator validator;
  late final BcbpParserService _bcbpParser;
  late final OcrParserService _ocrParser;
  late final ManualFlightParser _manualParser;

  /// Parses raw input string, prioritizing BCBP barcode structure, then
  /// falling back to OCR.
  ParsedFlight? parseRaw(String rawInput, {DateTime? referenceDate}) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return null;

    // Check if BCBP format (starts with 'M' and has minimum length)
    if (trimmed.startsWith('M') && trimmed.length >= 47) {
      final bcbpResult =
          _bcbpParser.parse(trimmed, referenceDate: referenceDate);
      if (bcbpResult != null && bcbpResult.hasRequiredRoute) {
        return bcbpResult;
      }
    }

    // Fall back to OCR heuristics
    return _ocrParser.parse(trimmed, referenceDate: referenceDate);
  }

  /// Parses a decoded barcode payload as IATA BCBP only. Null when the code
  /// isn't a boarding-pass barcode (e.g. an airline marketing QR).
  ParsedFlight? parseBarcode(String payload, {DateTime? referenceDate}) {
    final result =
        _bcbpParser.parse(payload.trim(), referenceDate: referenceDate);
    return (result != null && result.hasRequiredRoute) ? result : null;
  }

  /// Parses text read off a ticket (photo OCR) with the layout heuristics.
  ParsedFlight? parseText(String text, {DateTime? referenceDate}) =>
      _ocrParser.parse(text, referenceDate: referenceDate);

  /// Parses manual flight input.
  ParsedFlight parseManual({
    required String flightNumber,
    required String originIata,
    required String destinationIata,
    DateTime? departureDateTime,
    String? gate,
    String? seat,
  }) {
    return _manualParser.parse(
      flightNumber: flightNumber,
      originIata: originIata,
      destinationIata: destinationIata,
      departureDateTime: departureDateTime,
      gate: gate,
      seat: seat,
    );
  }
}
