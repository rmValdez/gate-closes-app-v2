import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/core/airports/local_airport_registry.dart';
import 'package:gate_closes/features/boarding_pass/domain/enums/boarding_pass_source.dart';
import 'package:gate_closes/features/boarding_pass/domain/services/boarding_pass_coordinator.dart';
import 'package:gate_closes/features/boarding_pass/domain/services/ticket_extraction/ticket_extraction_pipeline.dart';
import 'package:gate_closes/features/boarding_pass/domain/services/ticket_extraction/ticket_extraction_strategy.dart';
import 'package:gate_closes/features/boarding_pass/domain/services/ticket_extraction/ticket_image_reader.dart';

class _FakeReader implements TicketImageReader {
  _FakeReader({this.barcode, this.text = '', this.barcodeError});

  final String? barcode;
  final String text;
  final Exception? barcodeError;
  int textReads = 0;

  @override
  Future<String?> readBarcode(String imagePath) async {
    if (barcodeError != null) throw barcodeError!;
    return barcode;
  }

  @override
  Future<String> readText(String imagePath) async {
    textReads++;
    return text;
  }
}

void main() {
  late BoardingPassCoordinator coordinator;

  const bcbp = 'M1DOE/JOHN            EABC123 MNLCEBPR 1847 268Y018A0001 100';

  setUpAll(() {
    LocalAirportRegistry.instance.loadFromJsonString('''
    [
      {"iata": "MNL", "name": "Ninoy Aquino", "city": "Manila", "countryCode": "PH", "timezone": "Asia/Manila", "airportType": "large"},
      {"iata": "CEB", "name": "Mactan-Cebu", "city": "Cebu", "countryCode": "PH", "timezone": "Asia/Manila", "airportType": "large"}
    ]
    ''');
    coordinator =
        BoardingPassCoordinator(validator: LocalAirportRegistry.instance);
  });

  TicketExtractionPipeline pipelineFor(TicketImageReader reader) =>
      TicketExtractionPipeline([
        BarcodeImageStrategy(reader, coordinator),
        OcrImageStrategy(reader, coordinator),
      ]);

  test('a boarding-pass barcode wins and OCR is never run', () async {
    final reader = _FakeReader(barcode: bcbp, text: 'FLIGHT XX 1 MNL-CEB');

    final result = await pipelineFor(reader).extract('ticket.jpg');

    expect(result!.source, BoardingPassSource.bcbp);
    expect(result.flightNumber, 'PR1847');
    expect(reader.textReads, 0);
  });

  test('no barcode: falls back to OCR of the printed text', () async {
    final reader = _FakeReader(text: 'FLIGHT PR 1847\nFROM MNL\nTO CEB');

    final result = await pipelineFor(reader).extract('ticket.jpg');

    expect(result!.source, BoardingPassSource.ocr);
    expect(result.hasRequiredRoute, isTrue);
  });

  test('a non-boarding-pass QR (e.g. airline promo URL) falls back to OCR',
      () async {
    final reader = _FakeReader(
      barcode: 'https://airline.example/app',
      text: 'FLIGHT PR 1847\nMNL - CEB',
    );

    final result = await pipelineFor(reader).extract('ticket.jpg');

    expect(result!.source, BoardingPassSource.ocr);
    expect(result.originIata, 'MNL');
  });

  test('a failing strategy is skipped, not fatal', () async {
    final reader = _FakeReader(
      barcodeError: Exception('decoder crashed'),
      text: 'FLIGHT PR 1847\nMNL - CEB',
    );

    final result = await pipelineFor(reader).extract('ticket.jpg');

    expect(result!.flightNumber, 'PR1847');
  });

  test('returns a partial result to pre-fill the form', () async {
    final reader = _FakeReader(text: 'Your trip MNL - CEB');

    final result = await pipelineFor(reader).extract('ticket.jpg');

    expect(result, isNotNull);
    expect(result!.hasRequiredRoute, isFalse);
    expect(result.originIata, 'MNL');
  });

  test('returns null when nothing usable was read', () async {
    final reader = _FakeReader(text: 'THANK YOU FOR SHOPPING');

    expect(await pipelineFor(reader).extract('ticket.jpg'), isNull);
  });
}
