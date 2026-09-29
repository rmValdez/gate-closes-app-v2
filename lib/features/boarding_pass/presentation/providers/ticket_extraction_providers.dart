import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/airports/local_airport_registry.dart';
import 'package:gate_closes/features/boarding_pass/data/datasources/ml_kit_ticket_image_reader.dart';
import 'package:gate_closes/features/boarding_pass/domain/services/boarding_pass_coordinator.dart';
import 'package:gate_closes/features/boarding_pass/domain/services/ticket_extraction/ticket_extraction_pipeline.dart';
import 'package:gate_closes/features/boarding_pass/domain/services/ticket_extraction/ticket_extraction_strategy.dart';
import 'package:gate_closes/features/boarding_pass/domain/services/ticket_extraction/ticket_image_reader.dart';
import 'package:gate_closes/features/boarding_pass/presentation/debug/ticket_fixture_capture.dart';

/// Debug builds only: records raw reads for the fixture capture tool. Always
/// null in release, so no raw ticket content is retained there.
final ticketCaptureRecorderProvider = Provider<RecordingTicketImageReader?>(
  (ref) => kDebugMode
      ? RecordingTicketImageReader(const MlKitTicketImageReader())
      : null,
);

final ticketImageReaderProvider = Provider<TicketImageReader>(
  (ref) =>
      ref.watch(ticketCaptureRecorderProvider) ??
      const MlKitTicketImageReader(),
);

/// Order matters: exact barcode data first, OCR only as the fallback.
final ticketExtractionPipelineProvider = Provider<TicketExtractionPipeline>(
  (ref) {
    final reader = ref.watch(ticketImageReaderProvider);
    final coordinator =
        BoardingPassCoordinator(validator: LocalAirportRegistry.instance);
    return TicketExtractionPipeline([
      BarcodeImageStrategy(reader, coordinator),
      OcrImageStrategy(reader, coordinator),
    ]);
  },
);
