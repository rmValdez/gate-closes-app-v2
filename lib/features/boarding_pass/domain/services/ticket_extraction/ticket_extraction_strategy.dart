import 'package:gate_closes/features/boarding_pass/domain/entities/parsed_flight.dart';
import 'package:gate_closes/features/boarding_pass/domain/services/boarding_pass_coordinator.dart';
import 'package:gate_closes/features/boarding_pass/domain/services/ticket_extraction/ticket_image_reader.dart';

/// One way of turning a ticket photo into flight details. Strategies are
/// tried in order by `TicketExtractionPipeline`; add a new one (e.g. an
/// airline-specific layout) without touching the others or the UI.
abstract class TicketExtractionStrategy {
  const TicketExtractionStrategy();

  /// Short name for logs/diagnostics.
  String get name;

  /// Parsed details, or null if this strategy found nothing usable.
  Future<ParsedFlight?> extract(String imagePath);
}

/// Structured and exact: decodes the IATA BCBP barcode printed on the pass.
class BarcodeImageStrategy extends TicketExtractionStrategy {
  const BarcodeImageStrategy(this._reader, this._coordinator);

  final TicketImageReader _reader;
  final BoardingPassCoordinator _coordinator;

  @override
  String get name => 'barcode';

  @override
  Future<ParsedFlight?> extract(String imagePath) async {
    final payload = await _reader.readBarcode(imagePath);
    if (payload == null) return null;
    return _coordinator.parseBarcode(payload);
  }
}

/// Fallback for tickets without a usable barcode: reads the printed text and
/// parses it heuristically. Lower confidence — the user confirms every field.
class OcrImageStrategy extends TicketExtractionStrategy {
  const OcrImageStrategy(this._reader, this._coordinator);

  final TicketImageReader _reader;
  final BoardingPassCoordinator _coordinator;

  @override
  String get name => 'ocr';

  @override
  Future<ParsedFlight?> extract(String imagePath) async {
    final text = await _reader.readText(imagePath);
    return _coordinator.parseText(text);
  }
}
