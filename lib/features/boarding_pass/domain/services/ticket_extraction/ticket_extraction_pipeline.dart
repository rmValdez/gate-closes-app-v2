import 'package:gate_closes/core/utils/logger.dart';
import 'package:gate_closes/features/boarding_pass/domain/entities/parsed_flight.dart';
import 'package:gate_closes/features/boarding_pass/domain/services/ticket_extraction/ticket_extraction_strategy.dart';

/// Barcode → OCR → (manual, in the UI): runs [strategies] in order and stops
/// at the first complete result (flight number + both airports).
///
/// If none is complete, returns the most confident partial result so the
/// confirmation form is pre-filled with whatever was read; null only when
/// nothing at all was found. A strategy that throws is skipped, not fatal.
class TicketExtractionPipeline {
  const TicketExtractionPipeline(this.strategies);

  final List<TicketExtractionStrategy> strategies;

  Future<ParsedFlight?> extract(String imagePath) async {
    ParsedFlight? best;
    for (final strategy in strategies) {
      final ParsedFlight? result;
      try {
        result = await strategy.extract(imagePath);
      } on Object catch (e) {
        appLogger.w('Ticket extraction "${strategy.name}" failed: $e');
        continue;
      }
      if (result == null || !_hasAnyField(result)) continue;
      if (result.hasRequiredRoute) return result;
      if (best == null || result.confidence.overall > best.confidence.overall) {
        best = result;
      }
    }
    return best;
  }

  static bool _hasAnyField(ParsedFlight f) =>
      f.flightNumber.isNotEmpty ||
      f.originIata.isNotEmpty ||
      f.destinationIata.isNotEmpty;
}
